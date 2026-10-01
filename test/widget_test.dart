// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_bancaria/main.dart';

void main() {
  testWidgets('renders the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BancoApp());

    expect(find.text('Banca móvil'), findsOneWidget);
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
