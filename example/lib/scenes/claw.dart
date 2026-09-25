import 'dart:math' as math;

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scene_chrome.dart';

/// 抓娃娃机：机柜是 primary，摇杆面板是 secondary。
///
/// 立在桌上时机柜在上半、摇杆在下半，像一台街机；书本姿态左右分开。
/// 铰链角度只用来做效果：快速开合会摇晃机器，布局只看折痕。
class ClawPage extends StatefulWidget {
  const ClawPage({super.key});

  @override
  State<ClawPage> createState() => _ClawPageState();
}

class _ClawPageState extends State<ClawPage>
    with SingleTickerProviderStateMixin {
  final _claw = _Claw();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _angles = <(Duration, double)>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _claw.tick(dt.clamp(0, 0.05));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final angle = ArrangementScope.maybeOf(context)?.hinge?.angle;
    if (angle == null) {
      return;
    }
    final now = _last;
    _angles
      ..add((now, angle))
      ..removeWhere(
        (sample) => now - sample.$1 > const Duration(milliseconds: 400),
      );
    final swing = _angles.fold<double>(
      0,
      (most, sample) => math.max(most, (sample.$2 - angle).abs()),
    );
    if (swing > 0.6) {
      _angles.clear();
      _claw.shake();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _claw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      title: '抓娃娃机',
      api: '.split · ratio 0.6',
      dark: true,
      seed: const Color(0xFFFF2D95),
      notes: const [
        PoseNote(DevicePose.tabletop, '立在桌上就是一台街机：机柜在折痕上方，摇杆和按钮在下半的桌面上。'),
        PoseNote(DevicePose.book, '机柜在左，控制台在右，分界贴着折痕。'),
        PoseNote(DevicePose.flat, '没有折痕时按比例左右分开，机柜占 60%。'),
        PoseNote(DevicePose.closed, '外屏更高，改成上下叠放，机柜仍在上。'),
      ],
      body: ArrangementLayout(
        style: const ArrangementStyle.split(
          ratio: 0.6,
          minPrimaryExtent: 260,
          minSecondaryExtent: 200,
        ),
        primary: _Cabinet(claw: _claw),
        secondary: _ControlPanel(claw: _claw),
      ),
    );
  }
}

enum _Phase { idle, dropping, grabbing, lifting, returning, releasing }

enum _Kind { face, star, heart }

class _Prize {
  _Prize(this.x, this.kind, this.color, this.name);

  double x;
  final _Kind kind;
  final Color color;
  final String name;
}

class _Claw extends ChangeNotifier {
  final _random = math.Random(7);

  double time = 0;
  double x = 0.55;
  double depth = 0;
  double steer = 0;
  double shaking = 0;
  _Phase phase = _Phase.idle;
  double _timer = 0;
  bool _slipChecked = false;
  _Prize? grabbed;
  String message = '推动摇杆，对准之后按「抓」';
  final shelf = <_Prize>[];

  late final prizes = <_Prize>[
    _Prize(0.24, _Kind.face, const Color(0xFFFFC857), '小黄脸'),
    _Prize(0.33, _Kind.star, const Color(0xFF5CE1E6), '蓝星星'),
    _Prize(0.42, _Kind.heart, const Color(0xFFFF5D8F), '粉红心'),
    _Prize(0.51, _Kind.face, const Color(0xFF7CFFB2), '薄荷脸'),
    _Prize(0.6, _Kind.star, const Color(0xFFFFE066), '金星星'),
    _Prize(0.69, _Kind.face, const Color(0xFFB693FF), '紫团子'),
    _Prize(0.78, _Kind.heart, const Color(0xFFFF8C42), '橘子心'),
    _Prize(0.87, _Kind.star, const Color(0xFFFF6B6B), '红星星'),
  ];

  bool get ready => phase == _Phase.idle;

  void drop() {
    if (!ready) {
      return;
    }
    phase = _Phase.dropping;
    steer = 0;
    message = '下爪……';
    notifyListeners();
  }

  void shake() {
    if (!ready) {
      return;
    }
    shaking = 1;
    for (final prize in prizes) {
      prize.x = (prize.x + (_random.nextDouble() - 0.5) * 0.16).clamp(
        0.2,
        0.92,
      );
    }
    message = '机器被晃了一下，娃娃换了位置';
    notifyListeners();
  }

  void tick(double dt) {
    time += dt;
    shaking = math.max(0, shaking - dt * 2.2);
    switch (phase) {
      case _Phase.idle:
        x = (x + steer * 0.5 * dt).clamp(0.18, 0.94);
      case _Phase.dropping:
        depth += dt * 0.9;
        if (depth >= 1) {
          depth = 1;
          phase = _Phase.grabbing;
          _timer = 0.35;
        }
      case _Phase.grabbing:
        _timer -= dt;
        if (_timer <= 0) {
          _grab();
          phase = _Phase.lifting;
          _slipChecked = false;
        }
      case _Phase.lifting:
        depth -= dt * 0.75;
        if (!_slipChecked && depth < 0.55) {
          _slipChecked = true;
          if (grabbed != null && _random.nextDouble() < 0.25) {
            grabbed!.x = x;
            prizes.add(grabbed!);
            message = '${grabbed!.name}从爪子里滑掉了';
            grabbed = null;
          }
        }
        if (depth <= 0) {
          depth = 0;
          phase = _Phase.returning;
        }
      case _Phase.returning:
        x -= dt * 0.6;
        if (x <= 0.07) {
          x = 0.07;
          phase = _Phase.releasing;
          _timer = 0.45;
        }
      case _Phase.releasing:
        _timer -= dt;
        if (_timer <= 0) {
          final prize = grabbed;
          if (prize != null) {
            shelf.add(prize);
            message = '抓到了${prize.name}！';
          } else if (!message.contains('滑掉')) {
            message = '空手而归，再来一次';
          }
          grabbed = null;
          phase = _Phase.idle;
          x = 0.3;
          if (prizes.isEmpty) {
            _restock();
          }
        }
    }
    notifyListeners();
  }

  void _grab() {
    _Prize? best;
    var bestDistance = 0.075;
    for (final prize in prizes) {
      final distance = (prize.x - x).abs();
      if (distance < bestDistance) {
        best = prize;
        bestDistance = distance;
      }
    }
    if (best != null && _random.nextDouble() < 0.8) {
      prizes.remove(best);
      grabbed = best;
      message = '夹住了${best.name}……';
    } else {
      message = '没夹住';
    }
  }

  void _restock() {
    for (final prize in shelf.take(6)) {
      prize.x = 0.22 + _random.nextDouble() * 0.68;
      prizes.add(prize);
    }
    shelf.clear();
    message = '补货完毕';
  }
}

// MARK: 机柜

class _Cabinet extends StatelessWidget {
  const _Cabinet({required this.claw});

  final _Claw claw;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B0616),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CabinetPainter(claw),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CabinetPainter extends CustomPainter {
  _CabinetPainter(this.claw) : super(repaint: claw);

  final _Claw claw;

  @override
  void paint(Canvas canvas, Size size) {
    final t = claw.time;
    canvas.save();
    canvas.translate(math.sin(t * 70) * claw.shaking * 7, 0);

    final margin = math.min(size.width, size.height) * 0.05;
    final cabinet = Rect.fromLTRB(
      margin,
      margin,
      size.width - margin,
      size.height - margin,
    );
    final radius = Radius.circular(
      math.min(cabinet.width, cabinet.height) * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cabinet, radius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF2D95), Color(0xFF7B2FF7)],
        ).createShader(cabinet),
    );

    // 边框跑马灯。
    final perimeter = RRect.fromRectAndRadius(cabinet.deflate(8), radius);
    final lights = (cabinet.width + cabinet.height) ~/ 22;
    final path = Path()..addRRect(perimeter);
    final metric = path.computeMetrics().first;
    for (var i = 0; i < lights; i++) {
      final pos = metric.getTangentForOffset(metric.length * i / lights)!;
      final on = ((t * 6).floor() + i) % 3 == 0;
      canvas.drawCircle(
        pos.position,
        3,
        Paint()..color = on ? const Color(0xFFFFF3B0) : const Color(0x55FFFFFF),
      );
    }

    final marqueeHeight = cabinet.height * 0.13;
    final marquee = Rect.fromLTWH(
      cabinet.left + 22,
      cabinet.top + 18,
      cabinet.width - 44,
      marqueeHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(marquee, const Radius.circular(12)),
      Paint()..color = const Color(0xFF1A0B2E),
    );
    final title = TextPainter(
      text: TextSpan(
        text: 'DUO  CLAW',
        style: TextStyle(
          fontSize: marqueeHeight * 0.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          color: const Color(0xFFFFF3B0),
          shadows: const [Shadow(color: Color(0xFFFF2D95), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: marquee.width);
    title.paint(
      canvas,
      marquee.center - Offset(title.width / 2, title.height / 2),
    );

    final glass = Rect.fromLTRB(
      cabinet.left + 22,
      marquee.bottom + 14,
      cabinet.right - 22,
      cabinet.bottom - 22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(16)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1B4F), Color(0xFF140A2A)],
        ).createShader(glass),
    );

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(glass, const Radius.circular(16)));

    // 出口。
    final chute = Rect.fromLTWH(
      glass.left,
      glass.bottom - glass.height * 0.28,
      glass.width * 0.13,
      glass.height * 0.28,
    );
    canvas.drawRect(chute, Paint()..color = const Color(0xFF0B0616));
    final stripe = Paint()
      ..color = const Color(0xFFFFE066)
      ..strokeWidth = 4;
    for (var i = 0; i < 5; i++) {
      final y = chute.top + i * 9.0;
      canvas.drawLine(
        Offset(chute.left, y),
        Offset(chute.right, y + 6),
        stripe,
      );
    }

    final prizeRadius = (glass.width * 0.055).clamp(12.0, 30.0);
    final floor = glass.bottom - 10;
    for (var i = 0; i < claw.prizes.length; i++) {
      final prize = claw.prizes[i];
      final lift = (i % 2) * prizeRadius * 0.6;
      _drawPrize(
        canvas,
        prize,
        Offset(glass.left + prize.x * glass.width, floor - prizeRadius - lift),
        prizeRadius,
      );
    }

    // 滑轨与爪子。
    canvas.drawRect(
      Rect.fromLTWH(glass.left, glass.top + 8, glass.width, 8),
      Paint()..color = const Color(0xFF8A8FA3),
    );
    final clawX = glass.left + claw.x * glass.width;
    final travel = floor - prizeRadius * 2.4 - (glass.top + 24);
    final head = Offset(clawX, glass.top + 24 + travel * claw.depth);
    canvas.drawLine(
      Offset(clawX, glass.top + 12),
      head,
      Paint()
        ..color = const Color(0xFFC9CCD6)
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: head, width: 26, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE0E3EA),
    );
    final closed = switch (claw.phase) {
      _Phase.grabbing || _Phase.lifting || _Phase.returning => true,
      _ => false,
    };
    final spread = closed ? 0.25 : 0.75;
    final arm = Paint()
      ..color = const Color(0xFFE0E3EA)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final armLength = prizeRadius * 1.6;
    for (final side in [-1, 1]) {
      final elbow =
          head + Offset(side * armLength * math.sin(spread), armLength * 0.7);
      final tip = elbow + Offset(-side * armLength * 0.35, armLength * 0.55);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx, head.dy + 6)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(tip.dx, tip.dy),
        arm,
      );
    }
    final held = claw.grabbed;
    if (held != null) {
      _drawPrize(canvas, held, head + Offset(0, armLength * 1.05), prizeRadius);
    }

    // 玻璃反光。
    canvas.drawPath(
      Path()
        ..moveTo(glass.left + glass.width * 0.55, glass.top)
        ..lineTo(glass.left + glass.width * 0.7, glass.top)
        ..lineTo(glass.left + glass.width * 0.4, glass.bottom)
        ..lineTo(glass.left + glass.width * 0.25, glass.bottom)
        ..close(),
      Paint()..color = const Color(0x12FFFFFF),
    );
    canvas.restore();
    canvas.restore();
  }

  void _drawPrize(Canvas canvas, _Prize prize, Offset center, double r) {
    final fill = Paint()..color = prize.color;
    final ink = Paint()..color = const Color(0xFF1A0B2E);
    switch (prize.kind) {
      case _Kind.face:
        canvas.drawCircle(center, r, fill);
        canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.15), r * 0.12, ink);
        canvas.drawCircle(center + Offset(r * 0.35, -r * 0.15), r * 0.12, ink);
        canvas.drawArc(
          Rect.fromCenter(
            center: center + Offset(0, r * 0.15),
            width: r * 0.8,
            height: r * 0.5,
          ),
          0.2,
          math.pi - 0.4,
          false,
          Paint()
            ..color = const Color(0xFF1A0B2E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..strokeCap = StrokeCap.round,
        );
      case _Kind.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? r * 1.1 : r * 0.5;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * radius;
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path..close(), fill);
      case _Kind.heart:
        final path = Path()
          ..moveTo(center.dx, center.dy + r * 0.9)
          ..cubicTo(
            center.dx - r * 1.6,
            center.dy - r * 0.1,
            center.dx - r * 0.6,
            center.dy - r * 1.2,
            center.dx,
            center.dy - r * 0.4,
          )
          ..cubicTo(
            center.dx + r * 0.6,
            center.dy - r * 1.2,
            center.dx + r * 1.6,
            center.dy - r * 0.1,
            center.dx,
            center.dy + r * 0.9,
          );
        canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(_CabinetPainter oldDelegate) => oldDelegate.claw != claw;
}

// MARK: 控制台

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.claw});

  final _Claw claw;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0B2E), Color(0xFF0B0616)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight * 1.4;
          final side = math.min(
            wide ? constraints.maxHeight * 0.62 : constraints.maxWidth * 0.36,
            160.0,
          );
          final controls = [
            _Joystick(claw: claw, size: side),
            _GrabButton(claw: claw, size: side * 0.8),
          ];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: wide
                ? Row(
                    children: [
                      controls[0],
                      const SizedBox(width: 24),
                      Expanded(child: _Scoreboard(claw: claw)),
                      const SizedBox(width: 24),
                      controls[1],
                    ],
                  )
                : Column(
                    children: [
                      _Scoreboard(claw: claw),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: controls,
                      ),
                      const Spacer(),
                      const Text(
                        '快速开合设备可以摇晃机器',
                        style: TextStyle(
                          color: Color(0xFF8C7FA8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.claw});

  final _Claw claw;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: claw,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF050308),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A2466)),
              ),
              child: Text(
                claw.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  color: Color(0xFF7CFFB2),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '战利品 ${claw.shelf.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final prize in claw.shelf)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: prize.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.claw, required this.size});

  final _Claw claw;
  final double size;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  double _dx = 0;

  void _update(double dx) {
    final limit = widget.size * 0.3;
    setState(() => _dx = dx.clamp(-limit, limit));
    widget.claw.steer = _dx / limit;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      onPanStart: (details) => _update(details.localPosition.dx - size / 2),
      onPanUpdate: (details) => _update(_dx + details.delta.dx),
      onPanEnd: (_) => _update(0),
      onPanCancel: () => _update(0),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFF2A1B45), Color(0xFF120824)],
          ),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              left: 10,
              child: Icon(Icons.chevron_left_rounded, color: Color(0xFF8C7FA8)),
            ),
            const Positioned(
              right: 10,
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8C7FA8),
              ),
            ),
            AnimatedContainer(
              duration: Duration(milliseconds: _dx == 0 ? 180 : 0),
              transform: Matrix4.translationValues(_dx, 0, 0),
              width: size * 0.42,
              height: size * 0.42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Color(0xFFFF8AC8), Color(0xFFFF2D95)],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x66FF2D95), blurRadius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrabButton extends StatelessWidget {
  const _GrabButton({required this.claw, required this.size});

  final _Claw claw;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: claw,
      builder: (context, _) {
        final ready = claw.ready;
        return GestureDetector(
          onTap: claw.drop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: ready
                    ? const [Color(0xFFFFE066), Color(0xFFFF8C42)]
                    : const [Color(0xFF6B5A3A), Color(0xFF4A3A28)],
              ),
              boxShadow: [
                BoxShadow(
                  color: ready ? const Color(0x88FF8C42) : Colors.transparent,
                  blurRadius: 20,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '抓',
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3A1600),
              ),
            ),
          ),
        );
      },
    );
  }
}
