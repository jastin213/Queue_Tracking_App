import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/widgets/admin_notification_snackbar.dart';

Future<GlobalKey<ScaffoldMessengerState>> _pumpMessenger(
  WidgetTester tester, {
  bool accessibleNavigation = false,
}) async {
  final key = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: key,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(accessibleNavigation: accessibleNavigation),
        child: child!,
      ),
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
  return key;
}

void _show(
  AdminNotificationSnackBarPresenter presenter,
  GlobalKey<ScaffoldMessengerState> messenger, {
  String eventKey = 'event-1',
  String message = 'Automatically approved customer',
  VoidCallback? onCheck,
}) {
  presenter.show(
    messenger: messenger.currentState!,
    eventKey: eventKey,
    content: Text(message),
    onCheck: onCheck ?? () {},
  );
}

void main() {
  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      'auto-dismisses after three seconds with accessibility $accessibleNavigation',
      (tester) async {
        final messenger = await _pumpMessenger(
          tester,
          accessibleNavigation: accessibleNavigation,
        );
        final presenter = AdminNotificationSnackBarPresenter();
        _show(presenter, messenger);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Automatically approved customer'), findsOneWidget);
        expect(find.text('CHECK'), findsOneWidget);
        final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackbar.duration, const Duration(seconds: 3));
        // The effective default is derived by Flutter; the separate real drag
        // test verifies downward swipe without overriding the existing theme.
        expect(snackbar.action?.textColor, Colors.white);
        expect(presenter.activeEventKey, 'event-1');

        await tester.pump(const Duration(milliseconds: 2600));
        expect(find.text('Automatically approved customer'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
        expect(presenter.activeEventKey, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('CHECK keeps its callback and fires only once before expiry', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    var checks = 0;
    _show(presenter, messenger, onCheck: () => checks++);
    await tester.pumpAndSettle();

    await tester.tap(find.text('CHECK'));
    expect(checks, 1);
    expect(presenter.activeEventKey, isNull);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(checks, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid popup replacement cancels the old dismissal timer', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    _show(presenter, messenger, message: 'Old notification');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    _show(
      presenter,
      messenger,
      eventKey: 'event-2',
      message: 'Newest notification',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Old notification'), findsNothing);
    expect(find.text('Newest notification'), findsOneWidget);
    expect(presenter.activeEventKey, 'event-2');

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(presenter.activeEventKey, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('downward swipe still dismisses the notification', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    _show(presenter, messenger);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SnackBar), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(presenter.activeEventKey, isNull);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit dismissal clears ownership and its timer', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    _show(presenter, messenger);
    await tester.pumpAndSettle();

    presenter.dismiss();
    expect(presenter.activeEventKey, isNull);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    messenger.currentState!.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 20),
        content: Text('Unrelated notification'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Unrelated notification'), findsOneWidget);
    messenger.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous outside replacement is not dismissed as owned', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    _show(presenter, messenger);
    await tester.pumpAndSettle();

    messenger.currentState!
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 20),
          content: Text('Unrelated replacement'),
        ),
      );
    presenter.dismiss();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Unrelated replacement'), findsOneWidget);
    expect(presenter.activeEventKey, isNull);
    messenger.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('new popup removes old queued messages without a later backlog', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    messenger.currentState!
      ..showSnackBar(const SnackBar(content: Text('Queued old first')))
      ..showSnackBar(const SnackBar(content: Text('Queued old second')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    _show(presenter, messenger, message: 'Only newest notification');
    await tester.pumpAndSettle();
    expect(find.text('Only newest notification'), findsOneWidget);
    expect(find.text('Queued old first'), findsNothing);
    expect(find.text('Queued old second'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(presenter.activeEventKey, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('several immediate shows leave only the newest popup', (
    tester,
  ) async {
    final messenger = await _pumpMessenger(tester);
    final presenter = AdminNotificationSnackBarPresenter();
    _show(presenter, messenger, eventKey: 'first', message: 'First popup');
    _show(presenter, messenger, eventKey: 'second', message: 'Second popup');
    _show(presenter, messenger, eventKey: 'third', message: 'Third popup');
    await tester.pumpAndSettle();

    expect(find.text('First popup'), findsNothing);
    expect(find.text('Second popup'), findsNothing);
    expect(find.text('Third popup'), findsOneWidget);
    expect(presenter.activeEventKey, 'third');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
