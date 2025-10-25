// lib/screens/saved_locations_screen.dart
import 'package:flutter/material.dart';
import '../core/location_models_and_service.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final LocationService _locationService = LocationService();
  List<SavedLocation> _mainLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loadedLocations = await _locationService.loadLocations();
      setState(() {
        _mainLocations = loadedLocations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('حدث خطأ أثناء تحميل البيانات: ${e.toString()}');
    }
  }

  Future<void> _saveData() async {
    await _locationService.saveLocations(_mainLocations);
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openLocationForm({
    SavedLocation? parentLocation,
    SavedLocation? locationToEdit,
  }) async {
    final isMain = parentLocation == null && locationToEdit == null;

    final result = await showDialog<SavedLocation>(
      context: context,
      builder: (ctx) => LocationFormDialog(
        location: locationToEdit,
        locationService: _locationService,
        isMain: isMain,
      ),
    );

    if (result != null) {
      setState(() {
        if (locationToEdit != null) {
          locationToEdit.name = result.name;
          locationToEdit.coordinates = result.coordinates;
          _showSnackbar('تم تعديل الموقع بنجاح!');
        } else if (parentLocation != null) {
          parentLocation.subLocations.add(
            SavedLocation(
              id: uuid.v4(),
              name: result.name,
              coordinates: result.coordinates,
            ),
          );
          _showSnackbar('تم إضافة الموقع الفرعي بنجاح!');
        } else {
          _mainLocations.add(
            SavedLocation(
              id: uuid.v4(),
              name: result.name,
              coordinates: result.coordinates,
            ),
          );
          _showSnackbar('تم إضافة الموقع الرئيسي بنجاح!');
        }
      });
      _saveData();
    }
  }

  void _deleteLocation(SavedLocation locationToDelete, {SavedLocation? parentLocation}) {
    setState(() {
      if (parentLocation != null) {
        parentLocation.subLocations.removeWhere((loc) => loc.id == locationToDelete.id);
        _showSnackbar('تم حذف الموقع الفرعي!');
      } else {
        _mainLocations.removeWhere((loc) => loc.id == locationToDelete.id);
        _showSnackbar('تم حذف الموقع الرئيسي!');
      }
    });
    _saveData();
  }

  Widget _buildActionsRow(SavedLocation location, {SavedLocation? parentLocation, required bool isMain}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMain)
          IconButton(
            icon: const Icon(Icons.add_box, color: Colors.green),
            tooltip: 'إضافة فرعي',
            onPressed: () => _openLocationForm(parentLocation: location),
          ),
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.orange),
          tooltip: 'تعديل',
          onPressed: () => _openLocationForm(locationToEdit: location),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'حذف',
          onPressed: () => _deleteLocation(location, parentLocation: parentLocation),
        ),
      ],
    );
  }

  Widget _buildLocationItem(SavedLocation location, {SavedLocation? parentLocation}) {
    final bool isMain = parentLocation == null;
    const double horizontalPadding = 8.0;

    if (isMain && location.subLocations.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          subtitle: Text('رئيسي: ${location.coordinates.toString()}'),
          leading: const Icon(Icons.location_on, color: Colors.indigo),
          trailing: _buildActionsRow(location, isMain: true),
          children: location.subLocations
              .map((subLoc) => Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: _buildLocationItem(subLoc, parentLocation: location),
          ))
              .toList(),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.only(bottom: 4, left: isMain ? horizontalPadding : 16, right: horizontalPadding),
      elevation: isMain ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isMain ? Colors.indigo.shade50 : Colors.blueGrey.shade50,
      child: ListTile(
        leading: Icon(isMain ? Icons.location_pin : Icons.subdirectory_arrow_right,
            color: isMain ? Colors.indigo : Colors.blueGrey),
        title: Text(location.name, style: TextStyle(fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text('الإحداثيات: ${location.coordinates.toString()}'),
        trailing: _buildActionsRow(location, parentLocation: parentLocation, isMain: isMain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواقع المحفوظة 📍'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mainLocations.isEmpty
          ? const Center(
        child: Text(
          'لا توجد مواقع محفوظة بعد.\nاضغط على + لإضافة موقع رئيسي.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _mainLocations.length,
        itemBuilder: (context, index) {
          return _buildLocationItem(_mainLocations[index]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLocationForm(),
        label: const Text('إضافة موقع رئيسي'),
        icon: const Icon(Icons.add_location_alt),
      ),
    );
  }
}

// --------------------------------------------------
// نموذج الإضافة/التعديل (LocationFormDialog)
// --------------------------------------------------

class LocationFormDialog extends StatefulWidget {
  final SavedLocation? location;
  final LocationService locationService;
  final bool isMain;

  const LocationFormDialog({
    super.key,
    this.location,
    required this.locationService,
    required this.isMain,
  });

  @override
  State<LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _longController;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _nameController = TextEditingController(text: widget.location!.name);
      _latController = TextEditingController(text: widget.location!.coordinates.latitude.toString());
      _longController = TextEditingController(text: widget.location!.coordinates.longitude.toString());
    }
    else {
      _nameController = TextEditingController();
      _latController = TextEditingController();
      _longController = TextEditingController();
      _fetchCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() => _isFetchingLocation = true);

    try {
      final coords = await widget.locationService.getCurrentLocation();
      _latController.text = coords.latitude.toString();
      _longController.text = coords.longitude.toString();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب الموقع الحالي بنجاح!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الموقع: ${e.toString().split(':').last.trim()}')));
    } finally {
      if(mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final latitude = double.tryParse(_latController.text) ?? 0.0;
      final longitude = double.tryParse(_longController.text) ?? 0.0;

      final resultLocation = SavedLocation(
        id: widget.location?.id ?? 'temp',
        name: name,
        coordinates: Coordinates(latitude, longitude),
      );

      Navigator.of(context).pop(resultLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.location != null
          ? 'تعديل الموقع'
          : (widget.isMain ? 'إضافة موقع رئيسي' : 'إضافة موقع فرعي')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: ElevatedButton.icon(
                  onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh),
                  label: Text(_isFetchingLocation ? 'جاري الجلب...' : 'تحديث الموقع الحالي (GPS)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الموقع', prefixIcon: Icon(Icons.label), border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال اسم' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(labelText: 'خط العرض (تلقائي)', prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => (value == null || double.tryParse(value) == null) ? 'قيمة غير صحيحة' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _longController,
                decoration: const InputDecoration(labelText: 'خط الطول (تلقائي)', prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => (value == null || double.tryParse(value) == null) ? 'قيمة غير صحيحة' : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _isFetchingLocation ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.location != null ? 'حفظ التعديل' : 'إضافة الموقع'),
        ),
      ],
    );
  }
}