import 'package:flutter_test/flutter_test.dart';
import 'package:libenet_lecture_assistant/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LibeNetApp());
    expect(find.byType(LibeNetApp), findsOneWidget);
  });
}
