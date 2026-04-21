import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import '../../config/app_themes.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late Animation<double> _floatAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    // Rotate animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ??
        (isDarkMode ? const Color(0xFFE0E0E0) : Colors.black);
    final subtitleColor = isDarkMode
        ? const Color.fromARGB(255, 255, 255, 255).withOpacity(0.9)
        : Theme.of(context).primaryColor.withOpacity(0.7);
    final backgroundColor = isDarkMode
        ? Theme.of(context)
            .scaffoldBackgroundColor // Použije barvu z tématu (tmavou)
        : Colors.white; // V light modu zůstane bílá

    return Scaffold(
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Zjistíme jestli se obsah vejde bez scrollu
                  final contentHeight = constraints.maxHeight;

                  return SingleChildScrollView(
                    physics:
                        const ClampingScrollPhysics(), // Méně agresivní scroll
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: contentHeight, // Minimálně výška obrazovky
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          // BEZ SPACER - použijeme spaceAround nebo spaceEvenly
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Skupina 1: Animace
                            _buildAnimatedIcon(isDarkMode),

                            // Skupina 2: Text a features
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTitle(textColor),
                                const SizedBox(height: 32),
                                _buildFeaturesList(
                                    isDarkMode, textColor, subtitleColor),
                              ],
                            ),

                            // Skupina 3: Tlačítko
                            _buildStartButton(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(bool isDarkMode) {
    final animationColor = AppThemes.getQualityColor('good', isDarkMode);
    final screenWidth = MediaQuery.of(context).size.width;
    final containerSize = math.min(screenWidth * 0.59, 280.0);

    return Container(
      width: containerSize,
      height: containerSize,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatController, _rotateController]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _rotateController.value * 2 * math.pi,
                  child: Container(
                    width: containerSize,
                    height: containerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: animationColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -_rotateController.value * 2 * math.pi,
                  child: Container(
                    width: containerSize * 0.8, // 80% hlavního kruhu
                    height: containerSize * 0.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: animationColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Pulsing center
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.95, end: 1.05),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  onEnd: () => setState(() {}),
                  child: Container(
                    width: containerSize * 0.6, // 60% hlavního kruhu
                    height: containerSize * 0.6,
                    decoration: BoxDecoration(
                      color: animationColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.air,
                      size: containerSize * 0.3, // Responsivní ikona
                      color: animationColor,
                    ),
                  ),
                ),
                // Floating particles - upravené pro menší orbit
                ..._buildFloatingParticles(isDarkMode, containerSize * 0.5),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFloatingParticles(bool isDarkMode, double orbitRadius) {
    final animationColor = AppThemes.getQualityColor('good', isDarkMode);
    return List.generate(6, (index) {
      final angle = (index * math.pi * 2 / 6);
      final x =
          math.cos(angle + _rotateController.value * 2 * math.pi) * orbitRadius;
      final y =
          math.sin(angle + _rotateController.value * 2 * math.pi) * orbitRadius;

      return Positioned(
        left: orbitRadius + x - 4, // Centrované podle orbitRadius
        top: orbitRadius + y - 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: animationColor.withValues(alpha: 0.8), // Zvýšena viditelnost
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }

  Widget _buildTitle(Color textColor) {
    return Text(
      'Vítejte v\nAir Quality Monitor',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: textColor,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFeaturesList(
      bool isDarkMode, Color textColor, Color subtitleColor) {
    final iconColor = AppThemes.getQualityColor('good', isDarkMode);
    final features = [
      {
        'icon': Icons.sensors,
        'title': 'Real-time monitoring',
        'subtitle': 'CO₂, teplota, vlhkost a tlak'
      },
      {
        'icon': Icons.bed,
        'title': 'Analýza spánku',
        'subtitle': 'Vyhodnocení kvality prostředí'
      },
      {
        'icon': Icons.trending_up,
        'title': 'Statistiky',
        'subtitle': 'Sledování trendů a historických dat'
      },
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 200)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: iconColor.withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature['subtitle'] as String,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartButton() {
    final StartColor = AppThemes.getQualityColor('good', true);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: StartColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const UserProfileScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Začít',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
