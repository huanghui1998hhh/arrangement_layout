import 'package:arrangement_layout_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows posture and can open a dialog', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('姿态：无'), findsOneWidget);
    expect(find.text('角度：不可用'), findsOneWidget);

    await tester.tap(find.text('打开对话框'));
    await tester.pumpAndSettle();

    expect(find.text('半开时应当落在折痕的一侧。'), findsOneWidget);
  });
}
