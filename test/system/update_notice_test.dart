import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

Harness behind(AvailableUpdate u) => Harness(
  services: MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    status: mockBehind(u),
  ),
);

bool buttonEnabled(WidgetTester t, String label) =>
    t.widget<HButton>(find.widgetWithText(HButton, label)).enabled;

void main() {
  group('security update notice', () {
    testWidgets(
      'full screen, severity shown, cannot be dismissed for 5 seconds',
      (t) async {
        setView(t);
        final h = behind(mockSecurityUpdate());
        await h.pump(t);
        expect(find.text('Security update'), findsOneWidget);
        expect(find.text('Severity: High'), findsOneWidget);
        expect(find.textContaining('in 5 seconds'), findsOneWidget);
        expect(buttonEnabled(t, 'Later (5)'), isFalse);
        expect(buttonEnabled(t, 'Update now (5)'), isFalse);

        // Accept, Back and the Home button all do nothing while it counts down.
        await press(t, [kEnter, kEscape, kRight, kEnter]);
        h.mock.pressHome();
        await t.pumpAndSettle();
        expect(find.text('Security update'), findsOneWidget);
        expect(h.services.mockJobs.started, isEmpty);

        // The presses above took well under a second of fake time.
        await t.pump(const Duration(seconds: 3));
        expect(find.textContaining('You can choose in'), findsOneWidget);
        expect(find.textContaining(RegExp(r'Later \(\d\)')), findsOneWidget);
        await press(t, [kEscape, kEnter]);
        expect(
          find.text('Security update'),
          findsOneWidget,
          reason: 'still locked',
        );

        await t.pump(const Duration(seconds: 2));
        expect(find.textContaining('Choose when to update.'), findsOneWidget);
        expect(buttonEnabled(t, 'Later'), isTrue);
        expect(buttonEnabled(t, 'Update now'), isTrue);
      },
    );

    testWidgets('Later closes it, and nothing is updated', (t) async {
      setView(t);
      final h = behind(mockSecurityUpdate(severity: SecuritySeverity.critical));
      await h.pump(t);
      expect(find.text('Severity: Critical'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kEnter]); // Later is focused first
      expect(find.text('Security update'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
      // The reminder banner is there instead.
      expect(
        find.textContaining('Security update 2026.10.3 is available'),
        findsOneWidget,
      );
    });

    testWidgets('Back after the countdown means Later', (t) async {
      setView(t);
      final h = behind(mockSecurityUpdate());
      await h.pump(t);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kEscape]);
      expect(find.text('Security update'), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('Update now starts the update with its progress page', (
      t,
    ) async {
      setView(t);
      final h = behind(mockSecurityUpdate());
      await h.pump(t);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kRight, kEnter]);
      expect(h.services.mockJobs.started.single.kind, JobKind.update);
      expect(find.text('Updating HinterOS'), findsOneWidget);
    });

    testWidgets('a return to Home inside the interval does not repeat it', (
      t,
    ) async {
      setView(t);
      final h = behind(mockSecurityUpdate());
      await h.pump(t);
      await t.pump(const Duration(seconds: 5));
      await press(t, [kEnter]);
      await openTab(t, 1);
      h.mock.pressHome();
      await t.pumpAndSettle();
      expect(find.text('Security update'), findsNothing);
      expect(find.textContaining('Security update 2026.10.3'), findsOneWidget);
    });
  });

  group('ordinary update reminder', () {
    testWidgets(
      'a banner on Home at startup and on every return, never modal',
      (t) async {
        setView(t);
        final h = behind(mockOrdinaryUpdate());
        await h.pump(t);
        expect(find.text('HinterOS 2026.10.2 is available.'), findsOneWidget);
        expect(find.text('Security update'), findsNothing);
        expect(focusLabel(), 'home/apps:0', reason: 'does not take focus');
        await press(t, [kUp, kUp, kRight, kDown]); // Games
        expect(find.textContaining('is available'), findsNothing);
        h.mock.pressHome();
        await t.pumpAndSettle();
        expect(find.text('HinterOS 2026.10.2 is available.'), findsOneWidget);
        // Back from another tab too.
        await press(t, [kUp, kUp, kRight, kRight, kDown]); // Apps
        await press(t, [kEscape]);
        expect(find.text('HinterOS 2026.10.2 is available.'), findsOneWidget);
        expect(h.services.mockJobs.started, isEmpty, reason: 'never automatic');
      },
    );

    testWidgets('the banner is one step up, and leads to Settings > Updates', (
      t,
    ) async {
      setView(t);
      final h = behind(mockOrdinaryUpdate());
      await h.pump(t);
      await press(t, [kUp]);
      expect(focusLabel(), 'update-banner/update-banner:0');
      await press(t, [kUp]);
      expect(focusLabel(), startsWith('tabs/'));
      await press(t, [kDown, kEnter]);
      expect(focusLabel(), 'settings-list/updates:0');
      expect(find.text('Updates'), findsWidgets);
    });

    testWidgets('no banner when the box is up to date', (t) async {
      setView(t);
      final h = Harness(
        services: MockSystemServices(iconDir: iconDir(), now: fixedNow),
      );
      await h.pump(t);
      expect(find.textContaining('is available'), findsNothing);
    });
  });
}
