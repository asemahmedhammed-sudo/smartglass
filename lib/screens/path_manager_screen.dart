// lib/screens/path_manager_screen.dart
import 'package:flutter/material.dart';
import '../core/location_models_and_service.dart';
import 'path_creation_screen.dart';

class PathManagerScreen extends StatefulWidget {
  const PathManagerScreen({super.key});

  @override
  State<PathManagerScreen> createState() => _PathManagerScreenState();
}

class _PathManagerScreenState extends State<PathManagerScreen> {
  final LocationService _locationService = LocationService();
  List<MovementPath> _paths = [];
  List<SavedLocation> _allLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final paths = await _locationService.loadPaths();
      final locations = await _locationService.loadLocations();

      List<SavedLocation> allSubLocations = [];
      for (var mainLoc in locations) {
        allSubLocations.addAll(mainLoc.subLocations);
      }

      setState(() {
        _paths = paths;
        _allLocations = allSubLocations;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackbar('خطأ في تحميل البيانات: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  String _getLocationNameById(String id) {
    try {
      return _allLocations.firstWhere((loc) => loc.id == id).name;
    } catch (e) {
      return 'موقع غير معروف';
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _deletePath(MovementPath path) async {
    setState(() {
      _paths.removeWhere((p) => p.pathId == path.pathId);
      _showSnackbar('تم حذف المسار: ${path.name}');
    });
    await _locationService.savePaths(_paths);
  }

  void _navigateAndRefresh({MovementPath? path}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PathCreationScreen(
          path: path,
          allLocations: _allLocations,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المسارات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paths.isEmpty
          ? const Center(
        child: Text('لا توجد مسارات محفوظة.\nاضغط على + لإضافة مسار جديد.', textAlign: TextAlign.center),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _paths.length,
        itemBuilder: (context, index) {
          final path = _paths[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ExpansionTile(
              title: Text(path.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('من: ${_getLocationNameById(path.startLocationId)}\nإلى: ${_getLocationNameById(path.endLocationId)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    tooltip: 'تعديل',
                    onPressed: () => _navigateAndRefresh(path: path),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'حذف',
                    onPressed: () => _deletePath(path),
                  ),
                ],
              ),
              children: [
                ...path.steps.map((step) => ListTile(
                  leading: CircleAvatar(child: Text('${step.stepNumber}')),
                  title: Text(step.eventDescription ?? 'خطوة عادية'),
                  subtitle: Text('الإحداثيات: ${step.coordinates.toString()}'),
                )).toList(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateAndRefresh(),
        label: const Text('إضافة مسار جديد'),
        icon: const Icon(Icons.add_road),
      ),
    );
  }
}