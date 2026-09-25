import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:arrangement_layout_example/scenes/cinema.dart';
import 'package:arrangement_layout_example/scenes/claw.dart';
import 'package:arrangement_layout_example/scenes/explore_map.dart';
import 'package:arrangement_layout_example/scenes/reader.dart';
import 'package:arrangement_layout_example/scenes/reminders.dart';
import 'package:arrangement_layout_example/scenes/scene_chrome.dart';
import 'package:flutter/material.dart';

/// 用 `--dart-define=ARRANGEMENT_DEMO_POSE=book|tabletop|flat|closed` 伪造一次
/// iPhone Duo 读数，在不能切换姿态的设备上预览各场景。留空时读真实设备。
const _demoPose = String.fromEnvironment('ARRANGEMENT_DEMO_POSE');

/// 用 `--dart-define=ARRANGEMENT_DEMO_SCENE=cinema` 直接打开某个场景，
/// 名字见 [_scenes] 的 `route`。
const _demoScene = String.fromEnvironment('ARRANGEMENT_DEMO_SCENE');

final _demoEvents = StreamController<IosFoldReading>.broadcast();
final _navigatorKey = GlobalKey<NavigatorState>();

/// 演示模式下切换姿态。可以在调试器里执行 `demoPose('tabletop')`。
void demoPose(String pose) => _demoEvents.add(_demoReading(pose));

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ArrangementController? _demoController;

  @override
  void initState() {
    super.initState();
    if (_demoPose.isNotEmpty) {
      _demoController = ArrangementController(foldEvents: _demoEvents.stream);
      demoPose(_demoPose);
    }
  }

  @override
  void dispose() {
    _demoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'arrangement_layout example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) {
        return ArrangementScope(
          controller: _demoController,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: _demoScene.isEmpty ? '/' : '/$_demoScene',
      routes: {
        '/': (_) => const ArrangementPage(),
        for (final scene in _scenes) '/${scene.route}': scene.page,
      },
    );
  }
}

IosFoldReading _demoReading(String pose) {
  final view = PlatformDispatcher.instance.implicitView!;
  final size = view.physicalSize / view.devicePixelRatio;
  const gap = 40.0;
  final vertical = Rect.fromLTWH(size.width / 2 - gap / 2, 0, gap, size.height);
  final horizontal = Rect.fromLTWH(
    0,
    size.height / 2 - gap / 2,
    size.width,
    gap,
  );
  IosReservedRegion fold(Rect bounds, {required bool active}) {
    return IosReservedRegion(
      kind: IosRegionKind.division,
      bounds: bounds,
      isActive: active,
    );
  }

  return switch (pose) {
    'book' => IosFoldReading(
      hinge: const HingeState(posture: HingePosture.partiallyOpen, angle: 1.9),
      regions: [fold(vertical, active: true)],
    ),
    'tabletop' => IosFoldReading(
      hinge: const HingeState(posture: HingePosture.partiallyOpen, angle: 1.7),
      regions: [fold(horizontal, active: true)],
    ),
    'closed' => const IosFoldReading(
      hinge: HingeState(posture: HingePosture.closed, angle: 0),
      regions: [],
    ),
    _ => IosFoldReading(
      hinge: const HingeState(posture: HingePosture.fullyOpen, angle: math.pi),
      regions: [fold(vertical, active: false)],
    ),
  };
}

class ArrangementPage extends StatelessWidget {
  const ArrangementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ArrangementScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ArrangementLayout'),
        actions: const [PosePill(), SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '声明两块内容的关系，由折痕决定摆放',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '进入任一场景后，合上、摊平、像书一样握着、或立在桌上，观察同一页面的变化。'
            '右上角的标签会实时显示当前姿态。',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('姿态：${_postureLabel(state.hinge?.posture)}'),
                        const SizedBox(height: 4),
                        Text('角度：${_angleLabel(state.hinge?.angle)}'),
                        const SizedBox(height: 8),
                        const Text('生效特征'),
                        ..._featureLines(state.displayFeatures),
                        const SizedBox(height: 4),
                        const Text('未生效特征'),
                        ..._featureLines(state.inactiveDisplayFeatures),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) {
                          return const AlertDialog(
                            title: Text('对话框'),
                            content: Text('半开时应当落在折痕的一侧。'),
                          );
                        },
                      );
                    },
                    child: const Text('打开对话框'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 560
                  ? 2
                  : 1;
              const spacing = 14.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final scene in _scenes)
                    SizedBox(
                      width: width,
                      child: _SceneCard(scene: scene),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene});

  final _Scene scene;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/${scene.route}'),
        child: Ink(
          height: 168,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: scene.colors,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(scene.icon, color: Colors.white, size: 28),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        scene.style,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Menlo',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  scene.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scene.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xE6FFFFFF), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Scene {
  const _Scene({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.style,
    required this.icon,
    required this.colors,
    required this.page,
  });

  final String route;
  final String title;
  final String subtitle;
  final String style;
  final IconData icon;
  final List<Color> colors;
  final WidgetBuilder page;
}

final _scenes = <_Scene>[
  _Scene(
    route: 'cinema',
    title: '桌面影院',
    subtitle: '摊平时控制条浮在画面上；立在桌上，画面在上、完整控制台在下。',
    style: '.overlay',
    icon: Icons.movie_filter_rounded,
    colors: const [Color(0xFF3B1C6E), Color(0xFFFF4FA3)],
    page: (_) => const CinemaPage(),
  ),
  _Scene(
    route: 'map',
    title: '地图探索',
    subtitle: '浮动卡片收起在地图上；折起来后列表离开地图，占据一侧并展开。',
    style: '.overlay',
    icon: Icons.map_rounded,
    colors: const [Color(0xFF0F5E4C), Color(0xFF47C28F)],
    page: (_) => const ExploreMapPage(),
  ),
  _Scene(
    route: 'reminders',
    title: '提醒事项',
    subtitle: '书本姿态以折痕为界分成列表和详情；外屏和桌面姿态只留列表。',
    style: '.split(.horizontal)',
    icon: Icons.checklist_rounded,
    colors: const [Color(0xFF0A4FB3), Color(0xFF3DA5FF)],
    page: (_) => const RemindersPage(),
  ),
  _Scene(
    route: 'reader',
    title: '双页阅读',
    subtitle: '像一本打开的书：两页贴着折痕对开，书脊阴影落在折痕上。',
    style: '.split(.horizontal)',
    icon: Icons.auto_stories_rounded,
    colors: const [Color(0xFF6D4C41), Color(0xFFD7A86E)],
    page: (_) => const ReaderPage(),
  ),
  _Scene(
    route: 'claw',
    title: '抓娃娃机',
    subtitle: '机柜在折痕上方，摇杆在桌面上。快速开合设备会摇晃机器。',
    style: '.split',
    icon: Icons.videogame_asset_rounded,
    colors: const [Color(0xFF7B2FF7), Color(0xFFFF2D95)],
    page: (_) => const ClawPage(),
  ),
];

String _postureLabel(HingePosture? posture) {
  return switch (posture) {
    null => '无',
    HingePosture.unknown => '未知',
    HingePosture.closed => '合上',
    HingePosture.partiallyOpen => '半开',
    HingePosture.fullyOpen => '完全展开',
  };
}

String _angleLabel(double? radians) {
  if (radians == null) {
    return '不可用';
  }
  final degrees = radians * 180 / math.pi;
  return '${radians.toStringAsFixed(2)} rad（${degrees.toStringAsFixed(0)}°）';
}

List<Widget> _featureLines(List<DisplayFeature> features) {
  if (features.isEmpty) {
    return const [Text('无')];
  }
  return [
    for (final feature in features)
      Text('${feature.type.name}  ${feature.state.name}  ${feature.bounds}'),
  ];
}
