// lib/core/location_models_and_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

// --------------------------------------------------
// 1. نماذج الإحداثيات والمواقع
// --------------------------------------------------

class Coordinates {
  final double latitude;
  final double longitude;
  Coordinates(this.latitude, this.longitude);

  @override
  String toString() => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      Coordinates(json['latitude'] as double, json['longitude'] as double);
}

class SavedLocation {
  final String id;
  String name;
  Coordinates coordinates;
  List<SavedLocation> subLocations;

  SavedLocation({
    required this.id,
    required this.name,
    required this.coordinates,
    List<SavedLocation>? subLocations,
  }) : subLocations = subLocations ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coordinates': coordinates.toJson(),
    'subLocations': subLocations.map((loc) => loc.toJson()).toList(),
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      coordinates: Coordinates.fromJson(json['coordinates'] as Map<String, dynamic>),
      subLocations: (json['subLocations'] as List<dynamic>?)
          ?.map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // التعديل الجذري لحل مشكلة القائمة المنسدلة
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedLocation &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class PathStep {
  final int stepNumber;
  Coordinates coordinates;
  String? eventDescription;

  PathStep({
    required this.stepNumber,
    required this.coordinates,
    this.eventDescription,
  });

  Map<String, dynamic> toJson() => {
    'stepNumber': stepNumber,
    'coordinates': coordinates.toJson(),
    'eventDescription': eventDescription,
  };

  factory PathStep.fromJson(Map<String, dynamic> json) =>
      PathStep(
        stepNumber: json['stepNumber'] as int,
        coordinates: Coordinates.fromJson(json['coordinates'] as Map<String, dynamic>),
        eventDescription: json['eventDescription'] as String?,
      );
}

class MovementPath {
  final String pathId;
  String name;
  String startLocationId;
  String endLocationId;
  List<PathStep> steps;

  MovementPath({
    required this.pathId,
    required this.name,
    required this.startLocationId,
    required this.endLocationId,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
    'pathId': pathId,
    'name': name,
    'startLocationId': startLocationId,
    'endLocationId': endLocationId,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  factory MovementPath.fromJson(Map<String, dynamic> json) =>
      MovementPath(
        pathId: json['pathId'] as String,
        name: json['name'] as String,
        startLocationId: json['startLocationId'] as String,
        endLocationId: json['endLocationId'] as String,
        steps: (json['steps'] as List<dynamic>)
            .map((s) => PathStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

// --------------------------------------------------
// 3. خدمة الموقع والتخزين
// --------------------------------------------------

class LocationService {
  static const _locationsKey = 'saved_locations_data';
  static const _pathsKey = 'movement_paths_data';

  Future<List<SavedLocation>> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_locationsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((jsonItem) => SavedLocation.fromJson(jsonItem as Map<String, dynamic>)).toList();
  }

  Future<void> saveLocations(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = locations.map((loc) => loc.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_locationsKey, jsonString);
  }

  Future<SavedLocation?> findParentLocation(String subLocationId) async {
    final allMainLocations = await loadLocations();
    for (var mainLoc in allMainLocations) {
      if (mainLoc.subLocations.any((subLoc) => subLoc.id == subLocationId)) {
        return SavedLocation(
          id: mainLoc.id,
          name: mainLoc.name,
          coordinates: mainLoc.coordinates,
          subLocations: [],
        );
      }
    }
    return null;
  }

  Future<void> savePaths(List<MovementPath> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = paths.map((p) => p.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_pathsKey, jsonString);
  }

  Future<List<MovementPath>> loadPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pathsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((jsonItem) => MovementPath.fromJson(jsonItem as Map<String, dynamic>)).toList();
  }

  Future<Coordinates> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('خدمات الموقع غير مفعلة.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض صلاحية الموقع.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('تم رفض صلاحية الموقع بشكل دائم. يرجى تفعيلها يدوياً.');
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return Coordinates(position.latitude, position.longitude);
  }
}