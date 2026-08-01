import 'package:flutter_test/flutter_test.dart';
import 'package:rixu/app.dart';

void main() {
  testWidgets('未配置云端时显示连接提示', (WidgetTester tester) async {
    await tester.pumpWidget(const RixuApp());

    expect(find.text('尚未连接云端项目'), findsOneWidget);
  });
}
