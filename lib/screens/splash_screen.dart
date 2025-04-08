import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'welcome_screen.dart';
import 'signin.dart';
import '../styles/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final bool showWelcomeScreen;

  const SplashScreen({Key? key, required this.showWelcomeScreen}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isNavigating = false;

  // ألوان حديثة أكثر جاذبية
  final Color _primaryColor = AppColors.blue;
  final Color _secondaryColor = const Color(0xFF10B981);
  final Color _accentColor = const Color(0xFFF59E0B);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      
      // تأخير الانتقال للشاشة التالية
      Future.delayed(const Duration(milliseconds: 2500), () {
        _navigateToNextScreen();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    if (_isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });
    
    if (widget.showWelcomeScreen) {
      // الانتقال إلى شاشة الترحيب
      Get.offAll(
        () => const WelcomeScreen(), 
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 500)
      );
    } else {
      // الانتقال إلى شاشة تسجيل الدخول
      Get.offAll(
        () => const Signin(), 
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 500)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          _buildBackgroundDecoration(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 60),
                _buildAppName(),
                const SizedBox(height: 20),
                _buildTagline(),
                const SizedBox(height: 60),
                _buildLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Animate(
      effects: [
        ScaleEffect(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
          begin: const Offset(0.2, 0.2),
          end: const Offset(1.0, 1.0),
        ),
        FadeEffect(duration: const Duration(milliseconds: 800)),
      ],
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _primaryColor.withOpacity(0.2),
              Colors.transparent,
            ],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: _backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: _primaryColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Image.asset(
                'assets/images/logo.png', // قم بوضع مسار شعار التطبيق هنا
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // في حال عدم وجود الشعار، سيتم عرض أيقونة افتراضية
                  return Icon(
                    Icons.admin_panel_settings,
                    size: 70,
                    color: _primaryColor,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return Animate(
      effects: [
        FadeEffect(
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 300),
        ),
        SlideEffect(
          begin: const Offset(0, 0.5),
          end: const Offset(0, 0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutQuad,
        ),
      ],
      child: Text(
        "نظام إدارة المشتركين",
        style: TextStyle(
          color: _textColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Animate(
      effects: [
        FadeEffect(
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 500),
        ),
        SlideEffect(
          begin: const Offset(0, 0.5),
          end: const Offset(0, 0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutQuad,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _backgroundColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          "حلول متكاملة لإدارة المشتركين وتتبع الاشتراكات",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textColor.withOpacity(0.9),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Animate(
      effects: [
        FadeEffect(
          duration: const Duration(milliseconds: 800),
          delay: const Duration(milliseconds: 700),
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        // الخلفية المتدرجة
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                _backgroundColor,
                Color.lerp(_backgroundColor, _primaryColor.withOpacity(0.3), 0.2)!,
                Color.lerp(_backgroundColor, _secondaryColor.withOpacity(0.2), 0.2)!,
              ],
            ),
          ),
        ),
        
        // Particles and decorations
        ...List.generate(50, (index) {
          final random = math.Random(42 + index);
          final size = random.nextDouble() * 3 + 1;
          final x = random.nextDouble() * MediaQuery.of(context).size.width;
          final y = random.nextDouble() * MediaQuery.of(context).size.height;
          
          Color particleColor;
          if (index % 5 == 0) {
            particleColor = _primaryColor;
          } else if (index % 5 == 1) {
            particleColor = _secondaryColor;
          } else if (index % 5 == 2) {
            particleColor = _accentColor;
          } else {
            particleColor = Colors.white;
          }
          
          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: particleColor.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: particleColor.withOpacity(0.1),
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        }),
        
        // Top blur effects
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        Positioned(
          top: 100,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _secondaryColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        // Bottom blur wave
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _primaryColor.withOpacity(0.05),
                ],
              ),
            ),
            child: const CustomPaint(
              painter: WavePainter(),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

// Painter that draws a wave effect
class WavePainter extends CustomPainter {
  const WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    // Starting point
    path.moveTo(0, size.height * 0.7);
    
    // Draw a smooth wave
    path.quadraticBezierTo(
      size.width * 0.25, 
      size.height * 0.5,
      size.width * 0.5, 
      size.height * 0.7,
    );
    
    path.quadraticBezierTo(
      size.width * 0.75, 
      size.height * 0.9,
      size.width, 
      size.height * 0.7,
    );
    
    // Complete the path
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw a second wave with different opacity
    final path2 = Path();
    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    
    path2.moveTo(0, size.height * 0.8);
    
    path2.quadraticBezierTo(
      size.width * 0.2, 
      size.height * 0.6,
      size.width * 0.4, 
      size.height * 0.8,
    );
    
    path2.quadraticBezierTo(
      size.width * 0.7, 
      size.height * 1.0,
      size.width, 
      size.height * 0.8,
    );
    
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}