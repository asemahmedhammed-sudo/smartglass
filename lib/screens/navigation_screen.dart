// lib/screens/navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/location_models_and_service.dart';
import '../services/accessibility_service.dart';
import 'path_creation_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final LocationService _locationService = LocationService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  SavedLocation? _currentSubLocation;
  SavedLocation? _targetSubLocation;
  MovementPath? _selectedPath;
  List<MovementPath> _candidatePaths = [];

  List<MovementPath> _availablePaths = [];
  List<SavedLocation> _allSubLocations = [];

  bool _isLoading = true;
  int _currentStepIndex = 0;

  Map<String, dynamic>? _gpsCheckResult;
  bool _isCheckingGps = false;

  @override
  void initState() {
    super.initState();
    _loadDataAndDetectStart();
  }

  // --------------------------------------------------
  // 1. منطق التحميل والكشف التلقائي عن البداية
  // --------------------------------------------------

  Future<void> _loadDataAndDetectStart() async {
    try {
      final allMainLocations = await _locationService.loadLocations();
      final allPaths = await _locationService.loadPaths();

      List<SavedLocation> subLocs = [];
      for (var mainLoc in allMainLocations) {
        subLocs.addAll(mainLoc.subLocations);
      }

      setState(() {
        _allSubLocations = subLocs;
        _availablePaths = allPaths;
        _gpsCheckResult = null;
        _isCheckingGps = false;
        _currentStepIndex = 0;
      });

      await _detectCurrentSubLocation(subLocs);

    } catch (e) {
      _showSnackbar('خطأ في تحميل البيانات أو جلب الموقع: ${e.toString().split(':').last.trim()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _detectCurrentSubLocation(List<SavedLocation> subLocs) async {
    try {
      final currentCoords = await _locationService.getCurrentLocation();
      double minDistance = 5.0;
      SavedLocation? nearestLocation;

      for (var loc in subLocs) {
        double distance = Geolocator.distanceBetween(
          currentCoords.latitude, currentCoords.longitude,
          loc.coordinates.latitude, loc.coordinates.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestLocation = loc;
        }
      }

      setState(() {
        _currentSubLocation = nearestLocation;

        if (_currentSubLocation != null) {
          // رسالة التأكيد تركت معلقة هنا لمنع التكرار المزعج في UI
        } else {
          _showSnackbar('فشل تحديد الموقع التلقائي. يرجى اختيار البداية يدوياً.');
        }
      });
    } catch (e) {
      // لا تعرض خطأ إذا كان سبب الفشل هو صلاحيات GPS
    }
  }

  // --------------------------------------------------
  // 2. منطق اختيار المسار ونقطة النهاية
  // --------------------------------------------------

  void _onTargetLocationSelected(SavedLocation? target) {
    if (_currentSubLocation == null && target != null) {
      _showSnackbar('يرجى تحديد موقع البداية أولاً.');
      return;
    }
    setState(() {
      _targetSubLocation = target;
      _selectedPath = null;
      _candidatePaths = [];

      if (target != null) {
        _candidatePaths = _availablePaths.where(
              (path) => path.startLocationId == _currentSubLocation!.id && path.endLocationId == target.id,
        ).toList();

        if (_candidatePaths.length == 1) {
          _selectedPath = _candidatePaths.first;
          _showSnackbar('تم العثور على مسار واحد وتم اختياره تلقائياً.');
        } else if (_candidatePaths.length > 1) {
          _showSnackbar('تم العثور على ${_candidatePaths.length} مسارات. يرجى اختيار واحد يدوياً.');
        }
      }
    });
  }

  // --------------------------------------------------
  // 3. منطق التوجيه اليدوي مع عرض الـ GPS
  // --------------------------------------------------

  void _advanceToNextStep() {
    if (_selectedPath == null || _currentStepIndex >= _selectedPath!.steps.length) return;

    // التقدم للمؤشر التالي
    setState(() {
      _currentStepIndex++;
    });

    // التحقق من الوصول النهائي (تم إصلاح مشكلة الترتيب)
    if (_currentStepIndex >= _selectedPath!.steps.length) {
      _showArrivalConfirmation(); // أولاً: عرض التهنئة
      _resetNavigation();       // ثانياً: إعادة تعيين الحالة

    } else {
      _showSnackbar('تم التقدم إلى الخطوة الجديدة.');
      _checkGpsProximityForStep();
    }
  }

  Future<void> _checkGpsProximityForStep() async {
    if (_selectedPath == null || _currentStepIndex >= _selectedPath!.steps.length) {
      setState(() => _gpsCheckResult = null);
      return;
    }

    final targetStep = _selectedPath!.steps[_currentStepIndex];
    setState(() {
      _isCheckingGps = true;
      _gpsCheckResult = null;
    });

    try {
      final currentCoords = await _locationService.getCurrentLocation();
      const double threshold = 5.0;
      final distance = Geolocator.distanceBetween(
        currentCoords.latitude, currentCoords.longitude,
        targetStep.coordinates.latitude, targetStep.coordinates.longitude,
      );

      setState(() {
        _gpsCheckResult = {
          'distance': distance,
          'isClose': distance <= threshold,
          'currentCoords': currentCoords,
        };
      });
    } catch (e) {
      setState(() {
        _gpsCheckResult = {'error': e.toString().split(':').last.trim()};
      });
    } finally {
      setState(() => _isCheckingGps = false);
    }
  }

  // --------------------------------------------------
  // 4. منطق إنشاء مسار جديد فوري
  // --------------------------------------------------

  void _createNewPath() async {
    if (_currentSubLocation == null || _targetSubLocation == null) {
      _showSnackbar('يجب تحديد موقع البداية والنهاية أولاً لإنشاء مسار.');
      return;
    }

    final newPath = MovementPath(
      pathId: uuid.v4(),
      name: 'مسار جديد من ${_currentSubLocation!.name} إلى ${_targetSubLocation!.name}',
      startLocationId: _currentSubLocation!.id,
      endLocationId: _targetSubLocation!.id,
      steps: [],
    );

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PathCreationScreen(
          path: newPath,
          allLocations: _allSubLocations,
        ),
      ),
    );

    if (result == true) {
      _showSnackbar('تم حفظ المسار الجديد بنجاح! يتم تحديث البيانات...');
      await _loadDataAndDetectStart();
      _onTargetLocationSelected(_targetSubLocation);
    }
  }


  // --------------------------------------------------
  // 5. واجهات المستخدم المساعدة (الـ Helpers)
  // --------------------------------------------------

  void _resetNavigation() {
    setState(() {
      _currentStepIndex = 0;
      _selectedPath = null;
      _targetSubLocation = null;
      _candidatePaths = [];
      _gpsCheckResult = null;
      _isCheckingGps = false;
    });
    _loadDataAndDetectStart();
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showArrivalConfirmation() {
    // حماية من القيمة الفارغة (Null check operator)
    final targetName = _targetSubLocation?.name ?? 'الوجهة';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 تم الوصول!'),
        content: Text('تهانينا، لقد وصلت إلى وجهتك: $targetName'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسناً')),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 6. البناء (Build Method)
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('التنقل')), body: const Center(child: CircularProgressIndicator()));
    }

    if (_selectedPath != null && _currentStepIndex < _selectedPath!.steps.length) {
      return _buildNavigationGuidanceScreen();
    }

    return _buildPathSelectionScreen();
  }

  // --------------------------------------------------
  // شاشة التوجيه الفعلي (Navigation Guidance Screen)
  // --------------------------------------------------

  Widget _buildNavigationGuidanceScreen() {
    if (_currentStepIndex >= _selectedPath!.steps.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetNavigation());
      return const Center(child: Text('جاري إنهاء التنقل...'));
    }

    final currentStep = _selectedPath!.steps[_currentStepIndex];
    final remainingSteps = _selectedPath!.steps.length - _currentStepIndex;
    final isLastStep = remainingSteps == 1;

    if (_gpsCheckResult == null && !_isCheckingGps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkGpsProximityForStep();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنقل خطوة بخطوة (يدوي)'),
        actions: [
          // زر الإغلاق في الأعلى (تم تصحيحه لاستخدام _resetNavigation)
          IconButton(onPressed: _resetNavigation, icon: const Icon(Icons.close), tooltip: 'إنهاء التنقل'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('الوجهة: ${_targetSubLocation?.name ?? 'غير محدد'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple)),
                    const SizedBox(height: 10),
                    Text('المسار: ${_selectedPath!.name}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('الخطوات المتبقية: ${isLastStep ? 1 : remainingSteps}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.purple, width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('الخطوة الحالية: ${currentStep.stepNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(isLastStep ? Icons.flag : Icons.arrow_forward_ios, color: isLastStep ? Colors.red : Colors.purple),
                      ],
                    ),
                    const Divider(),
                    Text('التوجيه:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      currentStep.eventDescription ?? (isLastStep ? 'توجه مباشرة نحو نقطة النهاية.' : 'استمر في المسار إلى النقطة التالية.'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.purple),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text('إحداثيات الخطوة المسجلة: ${currentStep.coordinates.toString()}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),

            // واجهة عرض مقارنة الـ GPS
            _buildGpsComparisonWidget(),

            const Spacer(),

            // 1. زر التقدم اليدوي
            ElevatedButton.icon(
              onPressed: _advanceToNextStep,
              icon: Icon(isLastStep ? Icons.flag_circle : Icons.navigate_next),
              label: Text(isLastStep ? 'أكد الوصول إلى الوجهة النهائية' : 'أكملت الخطوة الحالية ← الخطوة التالية'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: isLastStep ? Colors.red.shade700 : Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // 2. زر إيقاف التنقل الجديد
            TextButton.icon(
              onPressed: _resetNavigation,
              icon: const Icon(Icons.pause_circle_outline, color: Colors.blueGrey),
              label: const Text('إيقاف التنقل والعودة للاختيار', style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsComparisonWidget() {
    if (_isCheckingGps) {
      return Padding(
        padding: const EdgeInsets.only(top: 15.0),
        child: Center(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 10),
            Text('جاري جلب إحداثيات GPS للمقارنة...'),
          ],
        )),
      );
    }

    if (_gpsCheckResult?['error'] != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 15.0),
        child: Text('خطأ GPS: ${_gpsCheckResult!['error']}', style: const TextStyle(color: Colors.red)),
      );
    }

    if (_gpsCheckResult != null && _gpsCheckResult!['distance'] != null) {
      final distance = (_gpsCheckResult!['distance'] as num?)?.toDouble() ?? 0.0;
      final isClose = _gpsCheckResult!['isClose'] as bool? ?? false;
      final currentCoords = _gpsCheckResult!['currentCoords'] as Coordinates?;

      if (currentCoords == null) {
        return const Padding(
          padding: EdgeInsets.only(top: 15.0),
          child: Text('خطأ: لم يتم العثور على إحداثيات GPS', style: TextStyle(color: Colors.red)),
        );
      }

      return Card(
        margin: const EdgeInsets.only(top: 15),
        color: isClose ? Colors.lightGreen.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isClose ? Icons.check_circle : Icons.warning, color: isClose ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  Text('مقارنة GPS (للعرض فقط):', style: TextStyle(fontWeight: FontWeight.bold, color: isClose ? Colors.green.shade800 : Colors.orange.shade800)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _checkGpsProximityForStep,
                    tooltip: 'تحديث قراءة GPS',
                  )
                ],
              ),
              const Divider(),
              Text('موقعك الحالي (GPS): ${currentCoords.toString()}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                'البُعد عن الخطوة: ${distance.toStringAsFixed(2)} متر',
                style: TextStyle(fontWeight: FontWeight.bold, color: isClose ? Colors.green : Colors.orange),
              ),
              Text(
                isClose ? '✨ الموقع الفعلي قريب من إحداثيات الخطوة!' : '⚠️ الموقع الفعلي بعيد عن إحداثيات الخطوة.',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // --------------------------------------------------
  // شاشة اختيار المسار (Path Selection Screen) - الدوال المكتملة
  // --------------------------------------------------

  Widget _buildPathSelectionScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار مسار التنقل')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationSelectionCard(
              title: 'موقع البداية الحالي',
              location: _currentSubLocation,
              label: 'اختر موقع البداية يدوياً',
              items: _allSubLocations,
              onChanged: (loc) => setState(() {
                _currentSubLocation = loc;
                _targetSubLocation = null;
                _selectedPath = null;
                _candidatePaths = [];
              }),
            ),
            const SizedBox(height: 20),

            _buildLocationSelectionCard(
              title: 'الوجهة (نهاية المسار)',
              location: _targetSubLocation,
              label: 'اختر موقع النهاية',
              items: _allSubLocations,
              onChanged: _onTargetLocationSelected,
              enabled: _currentSubLocation != null,
            ),
            const SizedBox(height: 30),

            Text('حالة المسار المختار:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
            const SizedBox(height: 10),

            if (_currentSubLocation != null && _targetSubLocation != null)
              _buildPathStatusWidget(),

            if (_currentSubLocation == null || _targetSubLocation == null)
              const Text('يرجى تحديد البداية والنهاية أولاً.', style: TextStyle(color: Colors.grey)),

          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelectionCard({
    required String title,
    required SavedLocation? location,
    required String label,
    required List<SavedLocation> items,
    required Function(SavedLocation?) onChanged,
    bool enabled = true,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            if (location != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_pin, color: Colors.green),
                title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${location.id.substring(0, 8)}...'),
              ),
            DropdownButtonFormField<SavedLocation>(
              decoration: const InputDecoration(
                labelText: 'اختر من القائمة',
                border: OutlineInputBorder(),
              ),
              initialValue: location,
              onChanged: enabled ? onChanged : null,
              items: items.map((loc) => DropdownMenuItem<SavedLocation>(
                value: loc,
                child: Text(loc.name),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathStatusWidget() {
    if (_candidatePaths.isNotEmpty && _selectedPath == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.route, color: Colors.blue),
            title: Text('يوجد عدة مسارات متاحة!'),
            subtitle: Text('يرجى اختيار المسار المفضل للتنقل.'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<MovementPath>(
            decoration: const InputDecoration(
              labelText: 'اختر المسار المفضل',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedPath,
            onChanged: (path) {
              setState(() {
                _selectedPath = path;
                _showSnackbar('تم اختيار المسار: ${path!.name}');
              });
            },
            items: _candidatePaths.map((path) {
              return DropdownMenuItem<MovementPath>(
                value: path,
                child: Text('${path.name} (${path.steps.length} خطوة)'),
              );
            }).toList(),
          ),
        ],
      );
    }

    else if (_selectedPath != null) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text('المسار المختار: ${_selectedPath!.name}'),
            subtitle: Text('عدد الخطوات: ${_selectedPath!.steps.length}'),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _currentStepIndex = 0);
              _checkGpsProximityForStep();
            },
            icon: const Icon(Icons.directions_run),
            label: const Text('بدء التنقل الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
        ],
      );
    }

    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.warning_amber, color: Colors.orange),
            title: Text('لا يوجد مسار مسجل بين هذين الموقعين!'),
            subtitle: Text('هل تريد إنشاء مسار جديد الآن؟'),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _createNewPath,
            icon: const Icon(Icons.add_road),
            label: const Text('إنشاء مسار جديد وتخزينه'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }
  }
}