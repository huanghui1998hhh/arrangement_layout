import 'dart:math' as math;

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scene_chrome.dart';

/// 桌面影院：画面是背景，控制台是前景。
///
/// 摊平或合上时画面铺满，控制条浮在画面底部；立在桌上时画面去上半，
/// 控制台在下半展开成完整面板；书本姿态画面在左，控制台在右。
class CinemaPage extends StatefulWidget {
  const CinemaPage({super.key});

  @override
  State<CinemaPage> createState() => _CinemaPageState();
}

class _CinemaPageState extends State<CinemaPage>
    with SingleTickerProviderStateMixin {
  final _cinema = _Cinema();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _cinema.advance(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cinema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      title: '桌面影院',
      api: '.overlay · primary: 控制台 · secondary: 画面',
      dark: true,
      seed: const Color(0xFFFF4FA3),
      notes: const [
        PoseNote(DevicePose.flat, '画面铺满，控制条缩成一条毛玻璃浮层压在画面底部。'),
        PoseNote(DevicePose.closed, '同样是层叠：外屏上只有画面和一条浮动控制条。'),
        PoseNote(DevicePose.tabletop, '立在桌上：画面到上半远看，控制台落到下半的稳定面上，展开成完整面板。'),
        PoseNote(DevicePose.book, '画面在 leading，控制台在 trailing，合上后离外屏更近。'),
      ],
      body: ArrangementLayout(
        style: const ArrangementStyle.overlay(
          layeredAlignment: AlignmentDirectional.bottomCenter,
          layeredPadding: EdgeInsets.all(20),
          layeredConstraints: BoxConstraints(maxWidth: 720),
        ),
        primary: _Console(cinema: _cinema),
        secondary: _FilmView(cinema: _cinema),
      ),
    );
  }
}

class _Chapter {
  const _Chapter(this.start, this.title, this.colors);

  final double start;
  final String title;
  final List<Color> colors;
}

const _chapters = <_Chapter>[
  _Chapter(0, '出城', [Color(0xFF3B1C6E), Color(0xFFFF7A59)]),
  _Chapter(48, '海岸公路', [Color(0xFF12306B), Color(0xFFFF4FA3)]),
  _Chapter(102, '隧道', [Color(0xFF0B0F2A), Color(0xFF7B3FF2)]),
  _Chapter(160, '日落', [Color(0xFF5B1A4A), Color(0xFFFFB347)]),
  _Chapter(214, '夜航', [Color(0xFF050814), Color(0xFF2E6BFF)]),
];

const _subtitles = <(double, String)>[
  (0, '城市在后视镜里越来越小。'),
  (14, '“我们今晚开到海边，好吗？”'),
  (30, '收音机里放着一首没人记得名字的歌。'),
  (48, '公路贴着海岸线，一直弯到天边。'),
  (70, '“你看，太阳还没落下去。”'),
  (102, '隧道的灯一盏一盏往后退。'),
  (130, '出口那头，有一点橙色的光。'),
  (160, '整片天空都烧起来了。'),
  (188, '“就停在这儿吧。”'),
  (214, '天黑之后，路就只剩下两条白线。'),
  (236, '我们谁都没有说话。'),
];

class _Cinema extends ChangeNotifier {
  static const double total = 252;

  double position = 58;
  bool playing = true;
  bool subtitles = true;
  double volume = 0.7;

  int get chapter => _chapters.lastIndexWhere((c) => c.start <= position);

  String get line => _subtitles.lastWhere((s) => s.$1 <= position).$2;

  void advance(double dt) {
    if (!playing) {
      return;
    }
    position = (position + dt) % total;
    notifyListeners();
  }

  void seek(double seconds) {
    position = seconds.clamp(0, total - 0.01);
    notifyListeners();
  }

  void toggle() {
    playing = !playing;
    notifyListeners();
  }

  void toggleSubtitles() {
    subtitles = !subtitles;
    notifyListeners();
  }

  void setVolume(double value) {
    volume = value;
    notifyListeners();
  }
}

String _clock(double seconds) {
  final s = seconds.floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// MARK: 画面

class _FilmView extends StatelessWidget {
  const _FilmView({required this.cinema});

  final _Cinema cinema;

  @override
  Widget build(BuildContext context) {
    final layered =
        ArrangementPane.of(context).presentation ==
        ArrangementPresentation.overlayLayered;
    final film = ListenableBuilder(
      listenable: cinema,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _SynthwavePainter(cinema.position)),
            if (cinema.subtitles)
              Positioned(
                left: 24,
                right: 24,
                bottom: layered ? 128 : 18,
                child: Text(
                  cinema.line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ),
            Positioned(
              top: 14,
              left: 16,
              child: _Badge(
                text:
                    '第 ${cinema.chapter + 1} 章 · ${_chapters[cinema.chapter].title}',
              ),
            ),
          ],
        );
      },
    );
    return ColoredBox(
      color: Colors.black,
      child: layered
          ? film
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: film,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _SynthwavePainter extends CustomPainter {
  _SynthwavePainter(this.t);

  final double t;

  static final _stars = List.generate(70, (i) {
    final r = math.Random(i * 7919);
    return Offset(r.nextDouble(), r.nextDouble() * 0.55);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.6;
    // 0 = 黄昏，1 = 深夜，随进度往返。
    final night = (math.sin(t / _Cinema.total * math.pi * 2 - 1.2) + 1) / 2;

    final skyTop = Color.lerp(
      const Color(0xFF2B1055),
      const Color(0xFF03040F),
      night,
    )!;
    final skyLow = Color.lerp(
      const Color(0xFFFF6B6B),
      const Color(0xFF3A1C71),
      night,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyLow],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + night * 0.6);
    for (var i = 0; i < _stars.length; i++) {
      final twinkle = 0.6 + 0.4 * math.sin(t * 2 + i);
      canvas.drawCircle(
        Offset(_stars[i].dx * w, _stars[i].dy * h),
        (i % 3 == 0 ? 1.4 : 0.8) * twinkle,
        starPaint,
      );
    }

    // 太阳：渐变圆，下半截被横条切开。
    final sunRadius = h * 0.24;
    final sunCenter = Offset(w / 2, horizon - sunRadius * 0.45);
    final sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, horizon), Paint());
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE66D), Color(0xFFFF4FA3)],
        ).createShader(sunRect),
    );
    final cut = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < 7; i++) {
      final y = sunCenter.dy + i * sunRadius * 0.16;
      final band = 1.5 + i * 1.6;
      canvas.drawRect(Rect.fromLTWH(0, y, w, band), cut);
    }
    canvas.restore();

    _mountains(canvas, size, horizon, t * 6, 0.16, const Color(0xFF2A0E4A));
    _mountains(canvas, size, horizon, t * 14, 0.09, const Color(0xFF16062B));

    // 地面与透视网格。
    final ground = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(ground, Paint()..color = const Color(0xFF0A0217));
    final grid = Paint()
      ..color = const Color(0xFFFF4FA3).withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    final vanish = Offset(w / 2, horizon);
    for (var i = -14; i <= 14; i++) {
      canvas.drawLine(vanish, Offset(w / 2 + i * w * 0.12, h), grid);
    }
    final phase = (t * 0.8) % 1;
    for (var i = 0; i < 14; i++) {
      final f = (i + phase) / 14;
      final y = horizon + (h - horizon) * f * f;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        grid..color = grid.color.withValues(alpha: 0.2 + f * 0.7),
      );
    }

    // 路面与中线。
    final road = Path()
      ..moveTo(w / 2 - 6, horizon)
      ..lineTo(w / 2 + 6, horizon)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF12051F));
    final dash = Paint()..color = const Color(0xFFFFE66D);
    for (var i = 0; i < 8; i++) {
      final f0 = ((i + phase * 2) / 8) % 1;
      final f1 = f0 + 0.04;
      final y0 = horizon + (h - horizon) * f0 * f0;
      final y1 = horizon + (h - horizon) * f1 * f1;
      final half0 = 1 + f0 * 5;
      final half1 = 1 + f1 * 5;
      canvas.drawPath(
        Path()
          ..moveTo(w / 2 - half0, y0)
          ..lineTo(w / 2 + half0, y0)
          ..lineTo(w / 2 + half1, y1)
          ..lineTo(w / 2 - half1, y1)
          ..close(),
        dash,
      );
    }
  }

  void _mountains(
    Canvas canvas,
    Size size,
    double horizon,
    double shift,
    double height,
    Color color,
  ) {
    final w = size.width;
    final path = Path()..moveTo(0, horizon);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final n = x + shift;
      final peak =
          (math.sin(n / 53) * 0.5 + math.sin(n / 21 + 1.3) * 0.3 + 0.9) *
          size.height *
          height;
      path.lineTo(x, horizon - peak.abs());
    }
    path
      ..lineTo(w, horizon)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SynthwavePainter oldDelegate) => oldDelegate.t != t;
}

// MARK: 控制台

class _Console extends StatelessWidget {
  const _Console({required this.cinema});

  final _Cinema cinema;

  @override
  Widget build(BuildContext context) {
    final floating = ArrangementPane.of(context).isFloating;
    return ListenableBuilder(
      listenable: cinema,
      builder: (context, _) {
        if (floating) {
          return _Hud(cinema: cinema);
        }
        return RevealBox(
          minSize: const Size(320, 250),
          child: _Deck(cinema: cinema),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.cinema});

  final _Cinema cinema;

  @override
  Widget build(BuildContext context) {
    return Glass(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          children: [
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: cinema.toggle,
              icon: Icon(
                cinema.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '霓虹公路',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_clock(cinema.position)} / ${_clock(_Cinema.total)}',
                        style: const TextStyle(
                          color: Color(0xFFB8BCC8),
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Scrubber(cinema: cinema, thin: true),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              color: Colors.white,
              onPressed: cinema.toggleSubtitles,
              icon: Icon(
                cinema.subtitles
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck({required this.cinema});

  final _Cinema cinema;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF4FA3);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14101F), Color(0xFF07080C)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy = constraints.maxHeight >= 420;
          final gap = SizedBox(height: roomy ? 20 : 4);
          // 内容比 pane 高时整体等比缩小，而不是溢出。
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 600 ? 48 : 28,
                    vertical: roomy ? 20 : 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '第 ${cinema.chapter + 1} 章 · ${_chapters[cinema.chapter].title}',
                                  style: const TextStyle(
                                    color: accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '霓虹公路',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            onPressed: cinema.toggleSubtitles,
                            icon: Icon(
                              cinema.subtitles
                                  ? Icons.subtitles_rounded
                                  : Icons.subtitles_off_outlined,
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            onPressed: () {},
                            icon: const Icon(Icons.cast_rounded),
                          ),
                        ],
                      ),
                      gap,
                      Column(
                        children: [
                          _Scrubber(cinema: cinema),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Text(
                                  _clock(cinema.position),
                                  style: const TextStyle(
                                    color: Color(0xFF9AA0AE),
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '-${_clock(_Cinema.total - cinema.position)}',
                                  style: const TextStyle(
                                    color: Color(0xFF9AA0AE),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      gap,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DeckButton(
                            icon: Icons.replay_10_rounded,
                            onTap: () => cinema.seek(cinema.position - 10),
                          ),
                          _DeckButton(
                            icon: Icons.skip_previous_rounded,
                            onTap: () => cinema.seek(
                              _chapters[math.max(cinema.chapter - 1, 0)].start,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              fixedSize: const Size(72, 72),
                            ),
                            onPressed: cinema.toggle,
                            icon: Icon(
                              cinema.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 40,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DeckButton(
                            icon: Icons.skip_next_rounded,
                            onTap: () => cinema.seek(
                              _chapters[math.min(
                                    cinema.chapter + 1,
                                    _chapters.length - 1,
                                  )]
                                  .start,
                            ),
                          ),
                          _DeckButton(
                            icon: Icons.forward_10_rounded,
                            onTap: () => cinema.seek(cinema.position + 10),
                          ),
                        ],
                      ),
                      if (roomy) ...[gap, _ChapterStrip(cinema: cinema)],
                      gap,
                      Row(
                        children: [
                          const Icon(
                            Icons.volume_down_rounded,
                            color: Color(0xFF9AA0AE),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: Colors.white70,
                                inactiveTrackColor: const Color(0xFF2A2D38),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: cinema.volume,
                                onChanged: cinema.setVolume,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.volume_up_rounded,
                            color: Color(0xFF9AA0AE),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeckButton extends StatelessWidget {
  const _DeckButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 34,
      color: Colors.white,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.cinema, this.thin = false});

  final _Cinema cinema;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: thin ? 3 : 5,
        activeTrackColor: const Color(0xFFFF4FA3),
        inactiveTrackColor: const Color(0x33FFFFFF),
        thumbColor: Colors.white,
        overlayShape: thin ? SliderComponentShape.noOverlay : null,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: thin ? 5 : 8),
      ),
      child: SizedBox(
        height: thin ? 16 : 40,
        child: Slider(
          value: cinema.position,
          max: _Cinema.total,
          onChanged: cinema.seek,
        ),
      ),
    );
  }
}

class _ChapterStrip extends StatelessWidget {
  const _ChapterStrip({required this.cinema});

  final _Cinema cinema;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chapters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final chapter = _chapters[index];
          final selected = index == cinema.chapter;
          return GestureDetector(
            onTap: () => cinema.seek(chapter.start),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 116,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: chapter.colors,
                ),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${index + 1}  ${chapter.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _clock(chapter.start),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
