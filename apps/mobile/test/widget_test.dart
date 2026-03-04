import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('KondateApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const KondateApp());
    expect(find.text('Kondate – Import Recipe'), findsOneWidget);
  });
}
