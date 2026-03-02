import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        title: 'Masaüstü Kayıt',
        home: Scaffold(
          body: Center(child: Text('Masaüstü Kayıt')),
        ),
      ),
    );
    expect(find.text('Masaüstü Kayıt'), findsOneWidget);
  });
}
