import 'dart:math' as math;

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';

import 'scene_chrome.dart';

/// 地图探索：结果面板是前景，地图是背景。
///
/// 没有折痕时面板浮在地图左上角并收起成一张卡片；折起来后地图和完整列表
/// 各占一侧。选中一家店，地图会移过去，两块内容始终是同一份状态。
class ExploreMapPage extends StatefulWidget {
  const ExploreMapPage({super.key});

  @override
  State<ExploreMapPage> createState() => _ExploreMapPageState();
}

class _ExploreMapPageState extends State<ExploreMapPage> {
  int _selected = 0;
  ArrangementEdge _edge = ArrangementEdge.trailing;

  void _select(int index) => setState(() => _selected = index);

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      title: '地图探索',
      api: '.overlay · overlayArrangementEdge',
      seed: const Color(0xFF1F8A70),
      notes: const [
        PoseNote(DevicePose.flat, '地图铺满，结果面板浮在左上角，只露出搜索框和当前选中的一家。'),
        PoseNote(DevicePose.closed, '外屏同样层叠，面板收起，不挡住地图主体。'),
        PoseNote(DevicePose.book, '面板离开地图，按所选的边占据一侧并展开成完整列表。'),
        PoseNote(DevicePose.tabletop, '地图在上半，列表落到下半，方便在桌上滑动挑选。'),
      ],
      body: ArrangementLayout(
        style: ArrangementStyle.overlay(
          horizontalEdge: _edge,
          layeredConstraints: const BoxConstraints(maxWidth: 380),
        ),
        primary: _ResultsPanel(
          selected: _selected,
          onSelect: _select,
          edge: _edge,
          onEdge: (edge) => setState(() => _edge = edge),
        ),
        secondary: _CityMap(selected: _selected, onSelect: _select),
      ),
    );
  }
}

class _Place {
  const _Place(
    this.name,
    this.rating,
    this.meters,
    this.tags,
    this.position,
    this.color,
  );

  final String name;
  final double rating;
  final int meters;
  final String tags;

  /// 在地图世界坐标里的位置，0 到 1。
  final Offset position;
  final Color color;
}

const _places = <_Place>[
  _Place(
    '折痕咖啡',
    4.8,
    180,
    '手冲 · 安静 · 有插座',
    Offset(0.42, 0.38),
    Color(0xFF8B5E3C),
  ),
  _Place('铰链与豆', 4.6, 320, '意式 · 可带宠物', Offset(0.58, 0.52), Color(0xFFD2691E)),
  _Place('双屏烘焙坊', 4.7, 450, '可颂 · 早午餐', Offset(0.31, 0.62), Color(0xFFC0392B)),
  _Place('江畔慢时光', 4.5, 620, '江景 · 露台', Offset(0.70, 0.30), Color(0xFF2E86AB)),
  _Place('书页咖啡馆', 4.9, 780, '书店 · 自习', Offset(0.22, 0.28), Color(0xFF6C5CE7)),
  _Place('夜航站', 4.4, 960, '营业到凌晨 · 精酿', Offset(0.78, 0.68), Color(0xFF2D3436)),
];

// MARK: 结果面板

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.selected,
    required this.onSelect,
    required this.edge,
    required this.onEdge,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final ArrangementEdge edge;
  final ValueChanged<ArrangementEdge> onEdge;

  @override
  Widget build(BuildContext context) {
    final pane = ArrangementPane.of(context);
    if (pane.isFloating) {
      return _CompactCard(selected: selected, onSelect: onSelect);
    }
    return RevealBox(
      minSize: const Size(320, 320),
      child: _FullList(
        selected: selected,
        onSelect: onSelect,
        edge: edge,
        onEdge: pane.axis == Axis.horizontal ? onEdge : null,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          const Text('咖啡', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = _places[selected];
    return Material(
      elevation: 8,
      shadowColor: const Color(0x55000000),
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SearchField(),
            const SizedBox(height: 10),
            Row(
              children: [
                _Thumb(place: place, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '★ ${place.rating} · ${place.meters} m · 营业中',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onSelect(
                    (selected - 1 + _places.length) % _places.length,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: () => onSelect((selected + 1) % _places.length),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${selected + 1} / ${_places.length} · 半折设备，完整列表会在另一侧展开',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullList extends StatelessWidget {
  const _FullList({
    required this.selected,
    required this.onSelect,
    required this.edge,
    required this.onEdge,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final ArrangementEdge edge;
  final ValueChanged<ArrangementEdge>? onEdge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '附近的咖啡',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_places.length} 个结果 · 按距离排序',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (onEdge != null)
                  SegmentedButton<ArrangementEdge>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ArrangementEdge.leading,
                        icon: Icon(Icons.align_horizontal_left_rounded),
                      ),
                      ButtonSegment(
                        value: ArrangementEdge.trailing,
                        icon: Icon(Icons.align_horizontal_right_rounded),
                      ),
                    ],
                    selected: {edge},
                    onSelectionChanged: (value) => onEdge!(value.first),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _SearchField(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                final isSelected = index == selected;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(index),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          _Thumb(place: place, size: 64),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    _Stars(rating: place.rating),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${place.rating} · ${place.meters} m',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  place.tags,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            IconButton.filledTonal(
                              tooltip: '步行 ${(place.meters / 80).ceil()} 分钟',
                              onPressed: () {},
                              icon: const Icon(Icons.directions_walk_rounded),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.place, required this.size});

  final _Place place;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [place.color, Color.lerp(place.color, Colors.amber, 0.5)!],
        ),
      ),
      child: Icon(Icons.coffee_rounded, color: Colors.white, size: size * 0.46),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i - 0.25
                ? Icons.star_rounded
                : rating >= i - 0.75
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: 15,
            color: const Color(0xFFF5A623),
          ),
      ],
    );
  }
}

// MARK: 地图

const _world = Size(1500, 1100);

class _CityMap extends StatefulWidget {
  const _CityMap({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<_CityMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layered =
        ArrangementPane.of(context).presentation ==
        ArrangementPresentation.overlayLayered;
    return LayoutBuilder(
      builder: (context, constraints) {
        final view = constraints.biggest;
        final place = _places[widget.selected];
        final target = Offset(
          place.position.dx * _world.width,
          place.position.dy * _world.height,
        );
        // 浮层压在左上角时，把焦点挪到右下方露出来的那块。
        final focus = layered
            ? Offset(view.width * 0.64, view.height * 0.6)
            : view.center(Offset.zero);
        final raw = focus - target;
        final offset = Offset(
          raw.dx.clamp(math.min(view.width - _world.width, 0), 0),
          raw.dy.clamp(math.min(view.height - _world.height, 0), 0),
        );
        return ClipRect(
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: offset, end: offset),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            builder: (context, value, child) {
              return OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: _world.width,
                maxWidth: _world.width,
                minHeight: _world.height,
                maxHeight: _world.height,
                child: Transform.translate(offset: value, child: child),
              );
            },
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _CityPainter()),
                ),
                Positioned(
                  left: _world.width * 0.5 - 40,
                  top: _world.height * 0.46 - 40,
                  child: _YouAreHere(pulse: _pulse),
                ),
                for (var i = 0; i < _places.length; i++)
                  _PinSlot(
                    place: _places[i],
                    selected: i == widget.selected,
                    onTap: () => widget.onSelect(i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PinSlot extends StatelessWidget {
  const _PinSlot({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final _Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = 160.0;
    const height = 96.0;
    return Positioned(
      left: place.position.dx * _world.width - width / 2,
      top: place.position.dy * _world.height - height,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(blurRadius: 8, color: Color(0x33000000)),
                  ],
                ),
                child: Text(
                  place.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedScale(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              scale: selected ? 1.3 : 1,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: place.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, color: Color(0x44000000)),
                      ],
                    ),
                    child: const Icon(
                      Icons.coffee_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(12, 8),
                    painter: _PinTail(place.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  _PinTail(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PinTail oldDelegate) => oldDelegate.color != color;
}

class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 20 + 56 * pulse.value,
                height: 20 + 56 * pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFF0A84FF,
                  ).withValues(alpha: 0.35 * (1 - pulse.value)),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A84FF),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  const _CityPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2EFE6),
    );

    const pitch = 92.0;
    // 街区底色，隔几块换一种深浅。
    for (var i = 0; i < w / pitch; i++) {
      for (var j = 0; j < h / pitch; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(i * pitch + 7, j * pitch + 7, pitch - 14, pitch - 14),
            const Radius.circular(6),
          ),
          Paint()
            ..color = (i * 7 + j * 3) % 5 == 0
                ? const Color(0xFFE2DDCF)
                : const Color(0xFFEAE6DB),
        );
      }
    }

    // 公园。
    final park = Paint()..color = const Color(0xFFCDE8B8);
    for (final rect in const [
      Rect.fromLTWH(191, 191, 170, 170),
      Rect.fromLTWH(835, 651, 78, 170),
      Rect.fromLTWH(7, 743, 262, 78),
      Rect.fromLTWH(1111, 99, 170, 78),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        park,
      );
    }

    // 江。
    final river = Path()
      ..moveTo(-40, h * 0.78)
      ..cubicTo(w * 0.25, h * 0.66, w * 0.4, h * 0.95, w * 0.62, h * 0.84)
      ..cubicTo(w * 0.8, h * 0.74, w * 0.88, h * 0.4, w + 40, h * 0.18)
      ..lineTo(w + 40, h * 0.3)
      ..cubicTo(w * 0.9, h * 0.5, w * 0.84, h * 0.84, w * 0.63, h * 0.94)
      ..cubicTo(w * 0.4, h * 1.04, w * 0.24, h * 0.76, -40, h * 0.88)
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0xFFA8D5F2));

    // 道路：先画描边再画路面。每隔三条是一条主路。
    final minor = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 6;
    for (var x = 0.0; x <= w; x += pitch) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), minor);
    }
    for (var y = 0.0; y <= h; y += pitch) {
      canvas.drawLine(Offset(0, y), Offset(w, y), minor);
    }
    final roads = <Path>[
      for (var y = pitch * 2; y <= h; y += pitch * 3)
        Path()
          ..moveTo(0, y)
          ..lineTo(w, y),
      for (var x = pitch * 3; x <= w; x += pitch * 3)
        Path()
          ..moveTo(x, 0)
          ..lineTo(x, h),
    ];
    final avenue = Path()
      ..moveTo(0, h * 0.95)
      ..quadraticBezierTo(w * 0.45, h * 0.35, w, h * 0.05);
    final casing = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFD9D4C4)
      ..strokeWidth = 16;
    final street = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 12;
    for (final road in roads) {
      canvas.drawPath(road, casing);
    }
    for (final road in roads) {
      canvas.drawPath(road, street);
    }
    canvas.drawPath(
      avenue,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFF2C14E)
        ..strokeWidth = 22,
    );
    canvas.drawPath(
      avenue,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFFFE08A)
        ..strokeWidth = 16,
    );

    _label(canvas, '滨江公园', const Offset(236, 266), const Color(0xFF4F7A3A));
    _label(canvas, '老城区', const Offset(560, 470), const Color(0xFF8A8474));
    _label(canvas, '中山大道', Offset(w * 0.56, h * 0.36), const Color(0xFFB8860B));
    _label(canvas, '青 江', Offset(w * 0.48, h * 0.88), const Color(0xFF3C7FB1));
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_CityPainter oldDelegate) => false;
}
