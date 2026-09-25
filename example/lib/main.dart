import 'dart:math' as math;
import 'dart:ui';

import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'arrangement_layout example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) {
        return ArrangementScope(child: child ?? const SizedBox.shrink());
      },
      home: const ArrangementPage(),
    );
  }
}

class ArrangementPage extends StatelessWidget {
  const ArrangementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = ArrangementScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('折叠屏状态')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('姿态：${_postureLabel(state.hinge?.posture)}'),
          const SizedBox(height: 8),
          Text('角度：${_angleLabel(state.hinge?.angle)}'),
          const SizedBox(height: 16),
          const Text('生效特征'),
          ..._featureLines(state.displayFeatures),
          const SizedBox(height: 16),
          const Text('未生效特征'),
          ..._featureLines(state.inactiveDisplayFeatures),
          const SizedBox(height: 24),
          FilledButton(
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
    );
  }
}

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
