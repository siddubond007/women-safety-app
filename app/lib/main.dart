import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFF7F8),
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
        scaffoldBackgroundColor: const Color(0xFFFFF7F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF79318A),
          brightness: Brightness.light,
        ),
      ),
      home: const SakhiWelcomeScreen(),
    );
  }
}

class SakhiWelcomeScreen extends StatelessWidget {
  const SakhiWelcomeScreen({super.key});

  static const Color plum = Color(0xFF321044);
  static const Color mutedPlum = Color(0xFF8D6C9D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8ECFA),
              Color(0xFFFFF8F2),
              Color(0xFFFFEAF2),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final width = constraints.maxWidth;
              final heroTop = math.max(210.0, height * 0.29).toDouble();
              final heroBottom = math.max(82.0, height * 0.115).toDouble();
              final brandTitleSize = width < 370 ? 39.0 : 43.0;
              final headlineSize = width < 370 ? 23.0 : 26.0;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const _SoftBackdropShapes(),
                  Positioned(
                    left: -2,
                    right: -2,
                    top: heroTop,
                    bottom: heroBottom,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const _HeroArtwork(),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.58, 0.80, 1.0],
                              colors: [
                                Color(0x00FFF7F5),
                                Color(0x00FFF7F5),
                                Color(0xBFFFF4F5),
                                Color(0xFFFFF4F5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 18,
                    right: 18,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 2),
                        const CustomPaint(
                          size: Size(86, 76),
                          painter: LotusLogoPainter(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sakhi',
                          style: TextStyle(
                            color: plum,
                            fontSize: brandTitleSize,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Safer Women. Stronger Together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: mutedPlum,
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'A Safer, Brighter Tomorrow\nfor Every Woman',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: plum,
                            fontSize: headlineSize,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.65,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Safety  •  Community  •  Wellness  •  Opportunities',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedPlum,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _PageProgressIndicator(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SoftBackdropShapes extends StatelessWidget {
  const _SoftBackdropShapes();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -82,
              right: -72,
              child: Container(
                width: 235,
                height: 235,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x99F4C6E8), Color(0x00F4C6E8)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: -104,
              child: Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x66E9C4F2), Color(0x00E9C4F2)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -58,
              bottom: 110,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55F7B7D8), Color(0x00F7B7D8)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageProgressIndicator extends StatelessWidget {
  const _PageProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF79318A),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 18,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE8CBE4),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 18,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE8CBE4),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

class LotusLogoPainter extends CustomPainter {
  const LotusLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h = size.height;
    final bounds = Offset.zero & size;

    final leftPetal = Path()
      ..moveTo(cx, h * 0.91)
      ..cubicTo(
        cx - 3,
        h * 0.66,
        size.width * 0.07,
        h * 0.56,
        size.width * 0.17,
        h * 0.21,
      )
      ..cubicTo(
        size.width * 0.43,
        h * 0.22,
        cx + 1,
        h * 0.46,
        cx,
        h * 0.91,
      )
      ..close();

    final rightPetal = Path()
      ..moveTo(cx, h * 0.91)
      ..cubicTo(
        cx + 3,
        h * 0.66,
        size.width * 0.93,
        h * 0.56,
        size.width * 0.83,
        h * 0.21,
      )
      ..cubicTo(
        size.width * 0.57,
        h * 0.22,
        cx - 1,
        h * 0.46,
        cx,
        h * 0.91,
      )
      ..close();

    final centerPetal = Path()
      ..moveTo(cx, h * 0.94)
      ..cubicTo(
        size.width * 0.30,
        h * 0.70,
        size.width * 0.34,
        h * 0.35,
        cx,
        h * 0.02,
      )
      ..cubicTo(
        size.width * 0.66,
        h * 0.35,
        size.width * 0.70,
        h * 0.70,
        cx,
        h * 0.94,
      )
      ..close();

    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB176C5), Color(0xFF8F4DA6)],
      ).createShader(bounds);
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF06BAA), Color(0xFFC33A91)],
      ).createShader(bounds);
    final centerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCB61AD), Color(0xFF9B429F)],
      ).createShader(bounds);

    canvas.drawPath(leftPetal, leftPaint);
    canvas.drawPath(rightPetal, rightPaint);
    canvas.drawPath(centerPetal, centerPaint);

    final separatorPaint = Paint()
      ..color = const Color(0xFFFFF8F8).withValues(alpha: 0.82)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, h * 0.62),
      Offset(cx, h * 0.91),
      separatorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LotusLogoPainter oldDelegate) => false;
}

class _HeroArtwork extends StatefulWidget {
  const _HeroArtwork();

  @override
  State<_HeroArtwork> createState() => _HeroArtworkState();
}

class _HeroArtworkState extends State<_HeroArtwork> {
  late final Future<Uint8List> _imageBytes = rootBundle
      .loadString('assets/images/sakhi_welcome_hero.jpg.b64')
      .then((encoded) => base64Decode(encoded.trim()));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageBytes,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        }
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFEAF2), Color(0xFFF3D9F4)],
            ),
          ),
        );
      },
    );
  }
}
