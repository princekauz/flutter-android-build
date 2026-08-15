// Sample widget test
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_android_build_demo/main.dart';

void main() {
  testWidgets('Home page renders the title', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Flutter APK Demo'), findsWidgets);
  });
}
