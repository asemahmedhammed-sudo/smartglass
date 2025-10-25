// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'saved_locations_screen.dart';
import 'path_manager_screen.dart';
import 'where_am_i_screen.dart';
import 'navigation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشاشة الرئيسية - نظام التنقل الداخلي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHomeButton(
              context,
              title: 'إدارة الأماكن (الرئيسي/الفرعي)',
              icon: Icons.map,
              screen: const SavedLocationsScreen(),
              color: Colors.indigo,
            ),
            const SizedBox(height: 20),
            _buildHomeButton(
              context,
              title: 'إدارة المسارات والتنقلات',
              icon: Icons.alt_route,
              screen: const PathManagerScreen(),
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 20),
            _buildHomeButton(
              context,
              title: 'أين أنا؟ (البحث عن الموقع الحالي)',
              icon: Icons.my_location,
              screen: const WhereAmIScreen(),
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            _buildHomeButton(
              context,
              title: 'بدء التنقل (Navigation)',
              icon: Icons.directions_run,
              screen: const NavigationScreen(),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context, {required String title, required IconData icon, required Widget screen, required Color color}) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
      },
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(280, 50),
      ),
    );
  }
}