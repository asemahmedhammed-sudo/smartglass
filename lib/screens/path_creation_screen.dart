// lib/screens/path_creation_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/location_models_and_service.dart';

class PathCreationScreen extends StatefulWidget {
  final MovementPath? path;
  final List<SavedLocation> allLocations;

  const PathCreationScreen({
    super.key,
    this.path,
    required this.allLocations,
  });

  @override
  State<PathCreationScreen> createState() => _PathCreationScreenState();
}

class _PathCreationScreenState extends State<PathCreationScreen> {
  final LocationService _locationService = LocationService();
  final _pathNameController = TextEditingController();
  List<PathStep> _steps = [];
  SavedLocation? _startLocation;
  SavedLocation? _endLocation;
  bool _isRecording = false;
  bool _isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.path != null) {
      _pathNameController.text = widget.path!.name;
      _steps = List.from(widget.path!.steps);
      _startLocation = _getLocationById(widget.path!.startLocationId);
      _endLocation = _getLocationById(widget.path!.endLocationId);
    } else {
      _attemptAutoDetectStartLocation();
    }
  }

  SavedLocation? _getLocationById(String id) {
    try {
      return widget.allLocations.firstWhere((loc) => loc.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _attemptAutoDetectStartLocation() async {
    setState(() => _isAutoDetecting = true);
    try {
      final currentCoords = await _locationService.getCurrentLocation();
      double minDistance = double.infinity;
      SavedLocation? nearestLocation;

      for (var loc in widget.allLocations) {
        double distance = Geolocator.distanceBetween(
          currentCoords.latitude,
          currentCoords.longitude,
          loc.coordinates.latitude,
          loc.coordinates.longitude,
        );
        if (distance < minDistance && distance < 20.0) {
          minDistance = distance;
          nearestLocation = loc;
        }
      }

      if (nearestLocation != null) {
        setState(() {
          _startLocation = nearestLocation;
          _showSnackbar('تم تحديد نقطة البداية تلقائياً: ${_startLocation!.name}');
        });
      } else {
        _showSnackbar('فشل تحديد الموقع تلقائياً. يرجى الاختيار يدوياً.');
      }
    } catch (e) {
      _showSnackbar('خطأ في جلب الموقع لتحديده التلقائي: ${e.toString().split(':').last.trim()}');
    } finally {
      setState(() => _isAutoDetecting = false);
    }
  }

  Future<void> _addStep() async {
    if (_startLocation == null) {
      _showSnackbar('يجب تحديد موقع البداية أولاً.');
      return;
    }
    setState(() => _isRecording = true);
    try {
      final currentCoords = await _locationService.getCurrentLocation();
      final stepNumber = _steps.length + 1;

      String? eventDescription = await _showEventDialog(stepNumber);

      setState(() {
        _steps.add(
          PathStep(
            stepNumber: stepNumber,
            coordinates: currentCoords,
            eventDescription: eventDescription,
          ),
        );
        _showSnackbar('تمت إضافة الخطوة رقم $stepNumber');
      });
    } catch (e) {
      _showSnackbar('خطأ في تسجيل الخطوة: ${e.toString().split(':').last.trim()}');
    } finally {
      setState(() => _isRecording = false);
    }
  }

  Future<String?> _showEventDialog(int stepNumber) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('وصف الحدث للخطوة $stepNumber'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اتجه شمال، انعطف لليمين، إلخ. (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('تخطي')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.isEmpty ? null : controller.text), child: const Text('حفظ الوصف')),
        ],
      ),
    );
  }

  Future<void> _finishAndSave() async {
    if (_pathNameController.text.isEmpty || _startLocation == null || _endLocation == null || _steps.isEmpty) {
      _showSnackbar('يرجى التأكد من اسم المسار، البداية، النهاية، والخطوات.');
      return;
    }

    List<MovementPath> allPaths = await _locationService.loadPaths();

    final newPath = MovementPath(
      pathId: widget.path?.pathId ?? uuid.v4(),
      name: _pathNameController.text,
      startLocationId: _startLocation!.id,
      endLocationId: _endLocation!.id,
      steps: _steps,
    );

    if (widget.path != null) {
      final index = allPaths.indexWhere((p) => p.pathId == newPath.pathId);
      if (index != -1) {
        allPaths[index] = newPath;
      }
    } else {
      allPaths.add(newPath);
    }

    await _locationService.savePaths(allPaths);
    _showSnackbar('تم حفظ المسار بنجاح!');
    if(mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSubLocations = widget.allLocations;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path != null ? 'تعديل المسار' : 'إنشاء مسار جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _pathNameController,
              decoration: const InputDecoration(labelText: 'اسم المسار (مثلاً: من غرفة النوم إلى المطبخ)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            _buildLocationDropdown(
              label: 'نقطة البداية (الموقع الفرعي الحالي)',
              value: _startLocation,
              items: availableSubLocations,
              onChanged: (loc) => setState(() => _startLocation = loc),
              isStart: true,
              isDetecting: _isAutoDetecting,
            ),
            const SizedBox(height: 15),
            _buildLocationDropdown(
              label: 'نقطة النهاية (الموقع الفرعي الهدف)',
              value: _endLocation,
              items: availableSubLocations,
              onChanged: (loc) => setState(() => _endLocation = loc),
              isStart: false,
              isDetecting: false,
            ),
            const SizedBox(height: 30),

            Text('الخطوات المسجلة: ${_steps.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addStep,
                    icon: _isRecording ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_road),
                    label: Text(_isRecording ? 'جاري التسجيل...' : 'إضافة خطوة جديدة (GPS)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_steps.isNotEmpty)
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${step.stepNumber}')),
                      title: Text(step.eventDescription ?? 'خطوة عادية'),
                      subtitle: Text(step.coordinates.toString()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _finishAndSave,
          icon: const Icon(Icons.check_circle),
          label: const Text('الانتهاء وحفظ المسار'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required SavedLocation? value,
    required List<SavedLocation> items,
    required Function(SavedLocation?) onChanged,
    required bool isStart,
    required bool isDetecting,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        DropdownButtonFormField<SavedLocation>(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: isDetecting ? 'جاري البحث التلقائي...' : 'اختر الموقع الفرعي',
            suffixIcon: isDetecting ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ) : null,
          ),
          value: value,
          onChanged: isDetecting ? null : onChanged,
          items: items.map<DropdownMenuItem<SavedLocation>>((SavedLocation loc) {
            return DropdownMenuItem<SavedLocation>(
              value: loc,
              child: Text(loc.name),
            );
          }).toList(),
          validator: (val) => val == null ? 'يجب اختيار الموقع' : null,
        ),
      ],
    );
  }
}