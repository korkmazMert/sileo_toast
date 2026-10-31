import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sileo_toast/sileo_toast.dart';
import 'package:sileo_toast_example/main.dart';

void main() {
  late SileoController toasts;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SileoExampleApp());
    toasts = Sileo.of(tester.element(find.byType(Scaffold)));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder button(String label) => find.widgetWithText(FilledButton, label);
  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('Success shows a toast with its title', (tester) async {
    await pumpApp(tester);
    await tap(tester, button('Success'));

    expect(find.text('Changes saved'), findsOneWidget);
    expect(toasts.items, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large + Action with Second button shows both buttons', (
    tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, chip('Large'));
    await tap(tester, find.text('Second button'));
    expect(find.text('Turn on Button first'), findsOneWidget);
    await tap(tester, find.text('Button'));
    await tap(tester, find.text('Second button'));
    await tap(tester, button('Action'));
    // Let the large toast open (autopilot or a tap).
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Update available'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clear all removes the toasts', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.text('Separate id'));
    await tap(tester, button('Success'));
    await tap(tester, button('Error'));
    expect(toasts.items, hasLength(2));

    await tap(tester, find.widgetWithText(OutlinedButton, 'Clear all'));
    await tester.pump(const Duration(seconds: 2));

    expect(toasts.items, isEmpty);
    expect(find.text('Changes saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
