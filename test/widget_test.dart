import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders header and form fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Quincaillerie Pro'), findsOneWidget);
    expect(find.text('Se Connecter'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
