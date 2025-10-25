// lib/screens/where_am_i_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/location_models_and_service.dart';

class WhereAmIScreen extends StatefulWidget {
  const WhereAmIScreen({super.key});

  @override
  State<WhereAmIScreen> createState() => _WhereAmIScreenState();
}

class _WhereAmIScreenState extends State<WhereAmIScreen> {
  final LocationService _locationService = LocationService();
  String _statusMessage = 'اضغط على "أين أنا؟" للبحث عن موقعك.';
  Map<String, dynamic>? _matchResult;
  bool _isSearching = false;

  static const double _locationThreshold = 5.0;
  static const double _stepThreshold = 10.0;

  Future<void> _findCurrentLocation() async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'جاري جلب الموقع والبحث عن تطابق...';
      _matchResult = null;
    });

    try {
      final currentCoords = await _locationService.getCurrentLocation();
      final allMainLocations = await _locationService.loadLocations();
      final allPaths = await _locationService.loadPaths();

      List<SavedLocation> allSubLocations = [];
      for (var mainLoc in allMainLocations) {
        allSubLocations.addAll(mainLoc.subLocations);
      }

      final closestLocationMatch = _findClosestLocation(currentCoords, allSubLocations);
      final closestPathMatch = _findClosestPathStep(currentCoords, allPaths);

      setState(() {
        if (closestLocationMatch != null && closestLocationMatch['distance'] <= _locationThreshold) {
          _displayLocationMatch(closestLocationMatch['location']);
        } else if (closestPathMatch != null && closestPathMatch['distance'] <= _stepThreshold) {
          _displayPathStepMatch(closestPathMatch['path'], closestPathMatch['step']);
        } else {
          _matchResult = null;
          _statusMessage = 'لا يوجد تطابق قريب (ضمن ${_locationThreshold} متر للمواقع و ${_stepThreshold} متر للمسارات).';
        }
        _isSearching = false;
      });

    } catch (e) {
      setState(() {
        _isSearching = false;
        _matchResult = null;
        _statusMessage = 'خطأ في جلب الموقع: ${e.toString().split(':').last.trim()}';
      });
    }
  }

  Map<String, dynamic>? _findClosestLocation(Coordinates current, List<SavedLocation> locations) {
    double minDistance = double.infinity;
    SavedLocation? closestLocation;

    for (var loc in locations) {
      final distance = Geolocator.distanceBetween(
        current.latitude, current.longitude,
        loc.coordinates.latitude, loc.coordinates.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestLocation = loc;
      }
    }
    return closestLocation != null ? {'location': closestLocation, 'distance': minDistance} : null;
  }

  Map<String, dynamic>? _findClosestPathStep(Coordinates current, List<MovementPath> paths) {
    double minDistance = double.infinity;
    MovementPath? closestPath;
    PathStep? closestStep;

    for (var path in paths) {
      for (var step in path.steps) {
        final distance = Geolocator.distanceBetween(
          current.latitude, current.longitude,
          step.coordinates.latitude, step.coordinates.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestPath = path;
          closestStep = step;
        }
      }
    }
    return closestPath != null ? {'path': closestPath, 'step': closestStep, 'distance': minDistance} : null;
  }

  void _displayLocationMatch(SavedLocation subLocation) async {
    final parentLocation = await _locationService.findParentLocation(subLocation.id);

    _matchResult = {
      'type': 'location',
      'title': 'أنت الآن في موقع فرعي قريب!',
      'icon': Icons.pin_drop,
      'details': {
        'الموقع الفرعي (الغرفة)': subLocation.name,
        'الموقع الرئيسي': parentLocation?.name ?? 'غير محدد',
        'الإحداثيات': subLocation.coordinates.toString(),
      },
      'color': Colors.indigo,
    };
    _statusMessage = 'تم العثور على موقعك!';
  }

  void _displayPathStepMatch(MovementPath path, PathStep step) async {
    final startLoc = await _locationService.findParentLocation(path.startLocationId);

    _matchResult = {
      'type': 'path',
      'title': 'أنت الآن على مسار مسجل!',
      'icon': Icons.alt_route,
      'details': {
        'اسم المسار': path.name,
        'الخطوة': 'رقم ${step.stepNumber}',
        'وصف الخطوة': step.eventDescription ?? 'خطوة عادية',
        'المسار': 'من: ${path.startLocationId} إلى: ${path.endLocationId}',
        'الموقع الرئيسي (المنطقة)': startLoc?.name ?? 'غير محدد',
      },
      'color': Colors.green.shade700,
    };
    _statusMessage = 'تم العثور على موقعك!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أين أنا؟'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isSearching ? null : _findCurrentLocation,
              icon: _isSearching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.gps_fixed),
              label: Text(_isSearching ? 'جاري البحث...' : 'أين أنا؟ (ابحث الآن)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            Center(
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _matchResult == null ? Colors.grey : Colors.black),
              ),
            ),
            const SizedBox(height: 30),

            if (_matchResult != null)
              Expanded(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: _matchResult!['color'], width: 2)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_matchResult!['icon'], size: 30, color: _matchResult!['color']),
                            const SizedBox(width: 10),
                            Text(
                              _matchResult!['title'],
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _matchResult!['color']),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        Expanded(
                          child: ListView(
                            children: _matchResult!['details'].entries.map<Widget>((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.black54))),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}