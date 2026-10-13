import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color sakhiPlum = Color(0xFF321044);
const Color sakhiPurple = Color(0xFF79318A);
const Color sakhiMutedPlum = Color(0xFF8D6C9D);
const Color sakhiBlush = Color(0xFFFFF4F7);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: sakhiBlush,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SakhiApp());
}

class SakhiApp extends StatelessWidget {
  const SakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakhi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: sakhiBlush,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sakhiPurple,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: sakhiBlush,
          foregroundColor: sakhiPlum,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const SakhiOnboardingScreen(),
    );
  }
}

class SakhiOnboardingScreen extends StatefulWidget {
  const SakhiOnboardingScreen({super.key});

  @override
  State<SakhiOnboardingScreen> createState() => _SakhiOnboardingScreenState();
}

class _SakhiOnboardingScreenState extends State<SakhiOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingContent> _content = [
    _OnboardingContent(
      title: 'A Safer, Brighter\nTomorrow for Every Woman',
      description: 'Safety  •  Community  •  Wellness  •  Opportunities',
    ),
    _OnboardingContent(
      title: 'Safety That Starts\nWith You',
      description:
          'Explore practical guidance and support designed to help you feel more prepared and confident.',
    ),
    _OnboardingContent(
      title: 'Stronger, Together',
      description:
          'A welcoming vision for wellbeing, community support, and new opportunities for every woman.',
    ),
  ];

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _continue() {
    if (_currentPage < _content.length - 1) {
      _goToPage(_currentPage + 1);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SakhiHomeScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8EDFA), Color(0xFFFFF9F5), Color(0xFFFFEDF3)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 44 : 22,
                      8,
                      wide ? 44 : 22,
                      10,
                    ),
                    child: Column(
                      children: [
                        const _SakhiBrandHeader(),
                        SizedBox(height: wide ? 18 : 8),
                        Expanded(
                          child: PageView(
                            key: const Key('sakhi-onboarding-page-view'),
                            controller: _pageController,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            onPageChanged: (page) {
                              setState(() => _currentPage = page);
                            },
                            children: const [
                              _OnboardingPage(
                                content: _content[0],
                                visual: _HeroPortrait(),
                              ),
                              _OnboardingPage(
                                content: _content[1],
                                visual: _FeatureIllustration(
                                  icon: Icons.shield_rounded,
                                  accent: Color(0xFF8B4D9C),
                                  label: 'SAFETY & GUIDANCE',
                                ),
                              ),
                              _OnboardingPage(
                                content: _content[2],
                                visual: _FeatureIllustration(
                                  icon: Icons.diversity_3_rounded,
                                  accent: Color(0xFFC64C91),
                                  label: 'COMMUNITY & WELLBEING',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _PageIndicator(
                          currentPage: _currentPage,
                          onSelected: _goToPage,
                        ),
                        const SizedBox(height: 10),
                        if (_currentPage < _content.length - 1)
                          Row(
                            children: [
                              TextButton(
                                key: const Key('skip-onboarding-button'),
                                onPressed: () => _goToPage(_content.length - 1),
                                style: TextButton.styleFrom(
                                  foregroundColor: sakhiMutedPlum,
                                  minimumSize: const Size(76, 52),
                                ),
                                child: const Text('Skip'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                key: const Key('next-onboarding-button'),
                                onPressed: _continue,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Next'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: sakhiPurple,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(142, 52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('get-started-button'),
                              onPressed: _continue,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Get started'),
                              style: FilledButton.styleFrom(
                                backgroundColor: sakhiPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class _SakhiBrandHeader extends StatelessWidget {
  const _SakhiBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 62,
          height: 55,
          child: CustomPaint(painter: LotusLogoPainter()),
        ),
        const SizedBox(height: 1),
        const Text(
          'Sakhi',
          style: TextStyle(
            color: sakhiPlum,
            fontSize: 31,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Safer Women. Stronger Together.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sakhiMutedPlum,
            fontSize: 12.5,
            height: 1.25,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.content,
    required this.visual,
  });

  final _OnboardingContent content;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final copy = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              content.title,
              textAlign: wide ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                color: sakhiPlum,
                fontSize: wide ? 32 : 25,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.65,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content.description,
              textAlign: wide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: sakhiMutedPlum,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        if (wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 6, child: visual),
                const SizedBox(width: 34),
                Expanded(flex: 5, child: copy),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            children: [
              Expanded(flex: 7, child: visual),
              const SizedBox(height: 14),
              copy,
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPortrait extends StatefulWidget {
  const _HeroPortrait();

  @override
  State<_HeroPortrait> createState() => _HeroPortraitState();
}

class _HeroPortraitState extends State<_HeroPortrait> {
  late final Future<Uint8List> _imageBytes = rootBundle
      .loadString('assets/images/sakhi_welcome_hero.jpg.b64')
      .then((encoded) => base64Decode(encoded.replaceAll(RegExp(r'\s+'), '')));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE5F1), Color(0xFFF2E4FA), Color(0xFFFFF3E8)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19321044),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: FutureBuilder<Uint8List>(
          future: _imageBytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              );
            }
            if (snapshot.hasError) {
              return const _IllustrationFallback();
            }
            return const Center(
              child: CircularProgressIndicator(color: sakhiPurple),
            );
          },
        ),
      ),
    );
  }
}

class _IllustrationFallback extends StatelessWidget {
  const _IllustrationFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_rounded, size: 88, color: sakhiPurple),
          SizedBox(height: 12),
          Text(
            'A brighter tomorrow',
            style: TextStyle(
              color: sakhiPlum,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  const _FeatureIllustration({
    required this.icon,
    required this.accent,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE8F3), Color(0xFFF0E6FB), Color(0xFFFFF4EC)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 28,
            left: 28,
            child: _DecorativeCircle(color: Color(0x33C64C91), size: 58),
          ),
          const Positioned(
            right: 28,
            top: 62,
            child: _DecorativeCircle(color: Color(0x338B4D9C), size: 38),
          ),
          const Positioned(
            bottom: 70,
            left: 46,
            child: _DecorativeCircle(color: Color(0x339A64B1), size: 28),
          ),
          Container(
            width: 218,
            height: 218,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.73),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Center(child: Icon(icon, size: 108, color: accent)),
          ),
          Positioned(
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: accent.withOpacity(0.12)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: sakhiPlum,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.currentPage,
    required this.onSelected,
  });

  final int currentPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final selected = currentPage == index;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Go to onboarding page \${index + 1}',
          child: InkWell(
            key: Key('onboarding-dot-$index'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(index),
            child: SizedBox(
              width: 34,
              height: 28,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: selected ? 29 : 10,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? sakhiPurple : const Color(0xFFE5CBE5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class LotusLogoPainter extends CustomPainter {
  const LotusLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bottom = size.height * 0.96;
    final bounds = Offset.zero & size;

    final leftPetal = Path()
      ..moveTo(centerX, bottom)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.77,
        size.width * 0.02,
        size.height * 0.52,
        size.width * 0.16,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 0.39,
        size.height * 0.18,
        centerX - 2,
        size.height * 0.49,
        centerX,
        bottom,
      )
      ..close();

    final rightPetal = Path()
      ..moveTo(centerX, bottom)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.77,
        size.width * 0.98,
        size.height * 0.52,
        size.width * 0.84,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 0.61,
        size.height * 0.18,
        centerX + 2,
        size.height * 0.49,
        centerX,
        bottom,
      )
      ..close();

    final centerPetal = Path()
      ..moveTo(centerX, bottom)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.65,
        size.width * 0.34,
        size.height * 0.30,
        centerX,
        size.height * 0.02,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.30,
        size.width * 0.72,
        size.height * 0.65,
        centerX,
        bottom,
      )
      ..close();

    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB77AC7), Color(0xFF8E4DA6)],
      ).createShader(bounds);
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF26BAA), Color(0xFFC33991)],
      ).createShader(bounds);
    final centerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCB61AD), Color(0xFF99429F)],
      ).createShader(bounds);

    canvas.drawPath(leftPetal, leftPaint);
    canvas.drawPath(rightPetal, rightPaint);
    canvas.drawPath(centerPetal, centerPaint);

    final centerLine = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, size.height * 0.60),
      Offset(centerX, size.height * 0.91),
      centerLine,
    );
  }

  @override
  bool shouldRepaint(covariant LotusLogoPainter oldDelegate) => false;
}

class SakhiHomeScreen extends StatelessWidget {
  const SakhiHomeScreen({super.key});

  static const List<_HomeFeature> _features = [
    _HomeFeature(
      title: 'Safety & support',
      description: 'Guidance and safety resources',
      icon: Icons.shield_outlined,
      accent: Color(0xFF8B4D9C),
    ),
    _HomeFeature(
      title: 'Trusted contacts',
      description: 'A place for your support network',
      icon: Icons.favorite_border_rounded,
      accent: Color(0xFFC64C91),
    ),
    _HomeFeature(
      title: 'Wellness',
      description: 'Ideas for everyday wellbeing',
      icon: Icons.spa_outlined,
      accent: Color(0xFF9A6CB3),
    ),
    _HomeFeature(
      title: 'Community',
      description: 'Connection and opportunities',
      icon: Icons.diversity_3_outlined,
      accent: Color(0xFFB25A96),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sakhi',
          style: TextStyle(
            color: sakhiPlum,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0DDF7), Color(0xFFFFE8F0)],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Sakhi',
                      style: TextStyle(
                        color: sakhiPlum,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your journey to a safer, more supported tomorrow starts here.',
                      style: TextStyle(
                        color: sakhiMutedPlum,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Explore Sakhi',
                style: TextStyle(
                  color: sakhiPlum,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              GridView.builder(
                itemCount: _features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 13,
                  childAspectRatio: constraints.maxWidth >= 900 ? 1.12 : 1.18,
                ),
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return _HomeFeatureCard(
                    feature: feature,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _SakhiFeaturePreviewScreen(
                            feature: feature,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EDF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Preview build: service integrations and the backend are not connected yet. Do not rely on this prototype for emergency assistance.',
                  style: TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
    required this.feature,
    required this.onTap,
  });

  final _HomeFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: feature.accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(feature.icon, color: feature.accent, size: 27),
              ),
              const Spacer(),
              Text(
                feature.title,
                style: const TextStyle(
                  color: sakhiPlum,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                feature.description,
                style: const TextStyle(
                  color: sakhiMutedPlum,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SakhiFeaturePreviewScreen extends StatelessWidget {
  const _SakhiFeaturePreviewScreen({required this.feature});

  final _HomeFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: feature.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(feature.icon, size: 62, color: feature.accent),
                ),
                const SizedBox(height: 24),
                Text(
                  '\${feature.title} preview',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: sakhiPlum,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  feature.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'This is a UI preview only. The related service and backend integration have not been implemented yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
