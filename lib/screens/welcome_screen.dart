import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'signin.dart';
import '../styles/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _isNavigating = false;

  final Color _primaryColor = AppColors.blue;
  final Color _secondaryColor = const Color(0xFF10B981);
  final Color _accentColor = const Color(0xFFF59E0B);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _cardColor = const Color(0xFF1E293B);
  final Color _textColor = Colors.white;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'مرحبًا بك في نظام إدارة المشتركين',
      'description': 'تطبيق متكامل لإدارة ومتابعة جميع المشتركين في النظام بكل سهولة وكفاءة',
      'icon': Icons.dashboard_customize,
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    },
    {
      'title': 'إدارة الاشتراكات بكفاءة',
      'description': 'متابعة حالة المشتركين والتنبيه التلقائي عند قرب انتهاء الاشتراك مع إمكانية التجديد التلقائي',
      'icon': Icons.notification_important,
      'gradient': [Color(0xFFF59E0B), Color(0xFFB45309)],
    },
    {
      'title': 'إحصائيات متقدمة',
      'description': 'عرض تقارير وإحصائيات تفصيلية لمساعدتك في اتخاذ القرارات الصحيحة لتطوير عملك',
      'icon': Icons.bar_chart,
      'gradient': [Color(0xFF10B981), Color(0xFF047857)],
    },
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSeenWelcome();
      _controller.forward();
    });
  }

  Future<void> _checkSeenWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool seenWelcome = prefs.getBool('seen_welcome') ?? false;
      debugPrint("🔍 التحقق من عرض الترحيب سابقاً: $seenWelcome");
      
      if (seenWelcome && mounted && !_isNavigating) {
        debugPrint("⚠️ تم عرض شاشة الترحيب سابقاً، الانتقال إلى تسجيل الدخول");
        _navigateToSignIn();
      }
    } catch (e) {
      debugPrint("❌ خطأ في التحقق من عرض الترحيب: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markWelcomeAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_welcome', true);
      debugPrint("✅ تم تعيين seen_welcome = true");
    } catch (e) {
      debugPrint("❌ خطأ في حفظ حالة الترحيب: $e");
    }
  }

  void _navigateToSignIn() async {
    if (_isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });
    
    await _markWelcomeAsSeen();
    
    if (mounted) {
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
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(
                        title: _pages[index]['title'],
                        description: _pages[index]['description'],
                        icon: _pages[index]['icon'],
                        gradient: _pages[index]['gradient'],
                      );
                    },
                  ),
                ),
                
                _buildFooterActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _navigateToSignIn,
            style: TextButton.styleFrom(
              foregroundColor: _textColor.withOpacity(0.9),
              backgroundColor: _backgroundColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _textColor.withOpacity(0.2), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Animate(
              effects: [
                FadeEffect(duration: const Duration(milliseconds: 500)),
                SlideEffect(
                  begin: const Offset(-0.2, 0),
                  duration: const Duration(milliseconds: 500),
                ),
              ],
              child: const Text(
                "تخطي",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          _buildPageIndicators(),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Animate(
      effects: [
        FadeEffect(duration: const Duration(milliseconds: 500)),
        ScaleEffect(delay: const Duration(milliseconds: 300)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(
            _pages.length,
            (index) => _buildPageIndicator(index),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isCurrentPage = _currentPage == index;
    
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isCurrentPage ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isCurrentPage ? _primaryColor : _textColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            
            Animate(
              effects: [
                ScaleEffect(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutQuad,
                ),
                FadeEffect(duration: const Duration(milliseconds: 600)),
              ],
              child: _buildGradientIconWidget(icon, gradient),
            ),
            
            const SizedBox(height: 40),
            
            Animate(
              effects: [
                FadeEffect(duration: const Duration(milliseconds: 500)),
                SlideEffect(
                  begin: const Offset(0, 0.3),
                  end: const Offset(0, 0),
                  curve: Curves.easeOutQuad,
                ),
              ],
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
              
            const SizedBox(height: 24),
            
            Animate(
              effects: [
                FadeEffect(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 200),
                ),
                SlideEffect(
                  begin: const Offset(0, 0.2),
                  end: const Offset(0, 0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutQuad,
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor.withOpacity(0.9),
                    fontSize: 16,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientIconWidget(IconData icon, List<Color> gradient) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withOpacity(0.2),
            gradient[1].withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الحلقات الداخلية
          ...List.generate(3, (index) {
            final size = 150.0 - (index * 20);
            return Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gradient[0].withOpacity(0.1 + (index * 0.1)),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
          
          // مركز الدائرة مع الأيقونة
          Animate(
            effects: [
              ScaleEffect(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
              ),
            ],
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
          
          // النقاط الزخرفية
          ...List.generate(8, (index) {
            final angle = (index / 8) * 2 * math.pi;
            final radius = 80.0;
            final x = radius * math.cos(angle);
            final y = radius * math.sin(angle);
            
            return Positioned(
              left: 90 + x,
              top: 90 + y,
              child: _buildAnimatedDot(index, gradient[0]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(int index, Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _backgroundColor.withOpacity(0.9),
            _backgroundColor.withOpacity(0.6),
            _backgroundColor.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // زر التالي/ابدأ الآن
          Animate(
            effects: [
              FadeEffect(duration: const Duration(milliseconds: 500)),
              SlideEffect(
                begin: const Offset(0, 0.3),
                end: const Offset(0, 0),
                curve: Curves.easeOutQuad,
              ),
              ShimmerEffect(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 1200),
                color: Colors.white30,
              ),
            ],
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
                    );
                  } else {
                    _navigateToSignIn();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentPage < _pages.length - 1 ? "التالي" : "ابدأ الآن",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _currentPage < _pages.length - 1 
                        ? Icons.arrow_forward_ios 
                        : Icons.login,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // مؤشر السحب
          if (_currentPage < _pages.length - 1)
            Animate(
              effects: [
                FadeEffect(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1000),
                ),
                SlideEffect(
                  begin: const Offset(0, 0.2),
                  end: const Offset(0, 0),
                  duration: const Duration(milliseconds: 600),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _cardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swipe,
                            size: 16,
                            color: _textColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "اسحب للانتقال بين الصفحات",
                            style: TextStyle(
                              color: _textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        
        // الأشكال الزخرفية
        Positioned(
          top: -50,
          right: -20,
          child: _buildDecorationCircle(
            size: 150,
            color: _primaryColor.withOpacity(0.08),
          ),
        ),
        
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: -30,
          child: _buildDecorationCircle(
            size: 120,
            color: _secondaryColor.withOpacity(0.07),
          ),
        ),
        
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.15,
          right: -40,
          child: _buildDecorationCircle(
            size: 180,
            color: _accentColor.withOpacity(0.07),
          ),
        ),
        
        // الأمواج المتحركة
        Positioned(
          bottom: -40,
          left: -50,
          right: -50,
          child: _buildAnimatedWave(
            height: 180, 
            color: _primaryColor.withOpacity(0.07),
            duration: const Duration(seconds: 3),
            offset: 10,
          ),
        ),
        
        Positioned(
          bottom: -60,
          left: -70,
          right: -70,
          child: _buildAnimatedWave(
            height: 160, 
            color: _secondaryColor.withOpacity(0.05),
            duration: const Duration(seconds: 4),
            offset: 15,
          ),
        ),
        
        // النقاط العائمة الزخرفية
        ..._buildFloatingDots(),
      ],
    );
  }

  Widget _buildAnimatedWave({
    required double height,
    required Color color,
    required Duration duration,
    required double offset,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildDecorationCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  List<Widget> _buildFloatingDots() {
    final List<Widget> dots = [];
    final random = math.Random(42); // ثابت لضمان نفس النمط

    for (int i = 0; i < 30; i++) {
      final double size = random.nextDouble() * 3 + 1;
      final double left = random.nextDouble() * MediaQuery.of(context).size.width;
      final double top = random.nextDouble() * MediaQuery.of(context).size.height;
      
      final Color dotColor = [
        _primaryColor,
        _secondaryColor,
        _accentColor,
      ][random.nextInt(3)].withOpacity(0.3);

      dots.add(
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(0.5),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return dots;
  }
}