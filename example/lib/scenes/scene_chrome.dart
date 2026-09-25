import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';

/// 设备此刻的姿态，只用于展示。布局本身不读它。
enum DevicePose {
  none('普通屏幕', Icons.smartphone_rounded),
  closed('合上 · 外屏', Icons.crop_portrait_rounded),
  flat('完全展开', Icons.tablet_rounded),
  book('书本姿态', Icons.menu_book_rounded),
  tabletop('桌面姿态', Icons.laptop_rounded);

  const DevicePose(this.label, this.icon);

  final String label;
  final IconData icon;

  static DevicePose of(BuildContext context) {
    final state = ArrangementScope.maybeOf(context);
    if (state == null) {
      return DevicePose.none;
    }
    for (final feature in state.displayFeatures) {
      final separates =
          feature.type == DisplayFeatureType.hinge ||
          (feature.type == DisplayFeatureType.fold &&
              feature.state == DisplayFeatureState.postureHalfOpened);
      if (separates) {
        final bounds = feature.bounds;
        return bounds.height > bounds.width
            ? DevicePose.book
            : DevicePose.tabletop;
      }
    }
    return switch (state.hinge?.posture) {
      HingePosture.closed => DevicePose.closed,
      HingePosture.fullyOpen || HingePosture.partiallyOpen => DevicePose.flat,
      _ => DevicePose.none,
    };
  }
}

/// 某个姿态下这一页会变成什么样。
class PoseNote {
  const PoseNote(this.pose, this.text);

  final DevicePose pose;
  final String text;
}

/// 场景页外壳：顶栏在 arrangement 外面，主体交给 [body]。
class SceneScaffold extends StatelessWidget {
  const SceneScaffold({
    super.key,
    required this.title,
    required this.api,
    required this.notes,
    required this.body,
    this.dark = false,
    this.seed = Colors.indigo,
  });

  final String title;

  /// 顶栏下方的一行代码提示，例如 `.overlay`。
  final String api;
  final List<PoseNote> notes;
  final Widget body;
  final bool dark;
  final Color seed;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: dark ? const Color(0xFF07080C) : scheme.surface,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        const BackButton(),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            api,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const PosePill(),
                        IconButton(
                          tooltip: '各姿态下的形态',
                          icon: const Icon(Icons.info_outline_rounded),
                          onPressed: () => _showNotes(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                Expanded(child: SafeArea(top: false, child: body)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNotes(BuildContext context) {
    final current = DevicePose.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(api, style: const TextStyle(fontFamily: 'Menlo')),
                const SizedBox(height: 12),
                for (final note in notes)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: note.pose == current
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(note.pose.icon, size: 20),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 84,
                          child: Text(
                            note.pose.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(child: Text(note.text)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 顶栏里的姿态标签，折叠或展开时跟着变。
class PosePill extends StatelessWidget {
  const PosePill({super.key});

  @override
  Widget build(BuildContext context) {
    final pose = DevicePose.of(context);
    final scheme = Theme.of(context).colorScheme;
    final folded = pose == DevicePose.book || pose == DevicePose.tabletop;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: folded ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Row(
          key: ValueKey(pose),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pose.icon,
              size: 16,
              color: folded ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              pose.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: folded ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 半透明毛玻璃底板，浮层用。
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.tint = const Color(0x99101218),
  });

  final Widget child;
  final double radius;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 容器在呈现切换时会把 pane 从旧 frame 插值到新 frame。插值途中比 [minSize]
/// 小的时候，按 [minSize] 布局并裁掉多出来的部分，而不是挤压内容。
class RevealBox extends StatelessWidget {
  const RevealBox({super.key, required this.minSize, required this.child});

  final Size minSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minSize.width
            ? minSize.width
            : constraints.maxWidth;
        final height = constraints.maxHeight < minSize.height
            ? minSize.height
            : constraints.maxHeight;
        if (width == constraints.maxWidth && height == constraints.maxHeight) {
          return child;
        }
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: child,
          ),
        );
      },
    );
  }
}

/// 当前是否有一条正在切开屏幕的折痕。只用于装饰（例如书脊阴影）。
bool hasActiveFold(BuildContext context) {
  final pose = DevicePose.of(context);
  return pose == DevicePose.book || pose == DevicePose.tabletop;
}
