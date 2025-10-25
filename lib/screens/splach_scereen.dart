import 'package:flutter/material.dart';
import 'dart:math' as math;

  class SmartGuideSplashScreen extends StatefulWidget {
  const SmartGuideSplashScreen({Key? key}) : super(key: key);

  @override
  State<SmartGuideSplashScreen> createState() => _SmartGuideSplashScreenState();
}

class _SmartGuideSplashScreenState extends State<SmartGuideSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _dotsController;
  late AnimationController _featureController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _featureAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _featureController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _featureAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _featureController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _featureController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _dotsController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1128),
              Color(0xFF1C2541),
              Color(0xFF0B132B),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background circles
              ...List.generate(3, (index) => _buildFloatingCircle(index)),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo with animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildAnimatedLogo(),
                    ),

                    const SizedBox(height: 40),

                    // Title with fade animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildTitle(),
                    ),

                    const SizedBox(height: 16),

                    // Tagline with fade animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildTagline(),
                    ),

                    const SizedBox(height: 24),

                    // Description with fade animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildDescription(),
                    ),

                    const SizedBox(height: 40),

                    // Animated dots
                    _buildAnimatedDots(),

                    const Spacer(flex: 2),

                    // Feature icons with animation
                    FadeTransition(
                      opacity: _featureAnimation,
                      child: _buildFeatureIcons(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Version number
              Positioned(
                top: 20,
                right: 20,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'v1.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCircle(int index) {
    final sizes = [200.0, 150.0, 100.0];
    final offsets = [
      Offset(-50, -50),
      Offset(300, 600),
      Offset(250, 200),
    ];

    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Positioned(
          left: offsets[index].dx + (math.sin(_dotsController.value * 2 * math.pi) * 20),
          top: offsets[index].dy + (math.cos(_dotsController.value * 2 * math.pi) * 20),
          child: Container(
            width: sizes[index],
            height: sizes[index],
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFF2E8B9E).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E8B9E),
            Color(0xFF1D6A7A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E8B9E).withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.directions_walk,
          size: 70,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Colors.white, Color(0xFF2E8B9E)],
      ).createShader(bounds),
      child: Text(
        'SmartGuide',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF2E8B9E).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
          children: [
            TextSpan(
              text: '"',
              style: TextStyle(
                color: Color(0xFF2E8B9E),
                fontSize: 24,
              ),
            ),
            TextSpan(
              text: 'Guiding every step with\n',
              style: TextStyle(color: Color(0xFF2E8B9E)),
            ),
            TextSpan(
              text: 'intelligence.',
              style: TextStyle(color: Color(0xFF2E8B9E)),
            ),
            TextSpan(
              text: '"',
              style: TextStyle(
                color: Color(0xFF2E8B9E),
                fontSize: 24,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'AI-powered navigation for the\nvisually impaired.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.8),
          height: 1.5,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.33;
            final animValue = (_dotsController.value + delay) % 1.0;
            final scale = math.sin(animValue * math.pi) * 0.5 + 0.5;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 6),
              width: 12 + (scale * 4),
              height: 12 + (scale * 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2E8B9E).withOpacity(0.5 + scale * 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2E8B9E).withOpacity(scale * 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFeatureIcons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFeatureIcon(
            icon: Icons.volume_up_rounded,
            label: 'Voice Ready',
            delay: 0,
          ),
          _buildFeatureIcon(
            icon: Icons.visibility,
            label: 'High Contrast',
            delay: 200,
          ),
          _buildFeatureIcon(
            icon: Icons.touch_app,
            label: 'Touch Friendly',
            delay: 400,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon({
    required IconData icon,
    required String label,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1C2541),
                  border: Border.all(
                    color: Color(0xFF2E8B9E).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Color(0xFF2E8B9E),
                  size: 28,
                ),
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
