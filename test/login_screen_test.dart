import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flat_rent_manager/providers/auth_provider.dart';
import 'package:flat_rent_manager/screens/login_screen.dart';

Widget _app() {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('renders the sign-in form', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Rent Manager'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('requires a username and a password', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Required'), findsNWidgets(2));
  });

  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(_app());

    TextField passwordField() =>
        tester.widgetList<TextField>(find.byType(TextField)).last;

    expect(passwordField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
