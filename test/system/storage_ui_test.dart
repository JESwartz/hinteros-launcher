// Settings > Storage (session API 0.14): the ring (around, into, back out),
// who may open which home, the two clean-ups, the automatic clean-up and
// measuring.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/system/storage.dart';
import 'package:hinteros_launcher/src/ui/system/storage_section.dart';
import 'package:hinteros_launcher/src/ui/widgets.dart';

import '../support/harness.dart';
import '../support/nav_helpers.dart';

const _askPin = "Type the admin profile's PIN.";

Harness harness({String current = 'p1', bool measured = true}) {
  final s = MockSystemServices(
    iconDir: iconDir(),
    now: fixedNow,
    currentProfile: current,
    storageMeasured: measured,
    profileBox: MockProfileBox(
      now: fixedNow,
      profiles: [...MockProfileBox.defaultProfiles(), mockRobin()],
    ),
  );
  return Harness(services: s);
}

String? _text(Key k) {
  final f = find.byKey(k);
  if (f.evaluate().isEmpty) return null;
  return (f.evaluate().single.widget as Text).data;
}

String? get selectedName => _text(const ValueKey('storage-selected-name'));
String? get selectedSize => _text(const ValueKey('storage-selected-size'));
String? get level => _text(const ValueKey('storage-ring-level'));

/// Settings > Storage with the focus on the ring.
Future<Harness> openStorage(
  WidgetTester t, {
  String current = 'p1',
  bool measured = true,
}) async {
  setView(t);
  final h = harness(current: current, measured: measured);
  await h.pump(t);
  await enterSettingsEntry(t, 'storage');
  return h;
}

void main() {
  group('the ring', () {
    testWidgets('left and right go around, round the ends', (t) async {
      await openStorage(t);
      expect(focusLabel(), 'settings-detail/ring:0');
      expect(level, 'Disk');
      expect(selectedName, 'System');
      await press(t, [kRight]);
      expect(selectedName, 'Apps');
      await press(t, [kRight]);
      expect(selectedName, 'James');
      await press(t, [kRight, kRight]);
      expect(selectedName, 'Robin');
      // Left from the first goes to the last: free space.
      await press(t, [kLeft, kLeft, kLeft, kLeft, kLeft]);
      expect(selectedName, 'Free space');
      await press(t, [kLeft]);
      expect(selectedName, 'Other');
      // The focus stayed on the ring all along.
      expect(focusLabel(), 'settings-detail/ring:0');
    });

    testWidgets('A goes in, B goes out, then out of the screen', (t) async {
      await openStorage(t);
      await press(t, [kEnter]);
      expect(level, 'System');
      expect(selectedName, 'Generation 12');
      await press(t, [kRight]);
      expect(selectedName, 'Generation 11');
      // A on a generation does nothing (nothing in it).
      await press(t, [kEnter]);
      expect(level, 'System');
      await press(t, [kEscape]);
      expect(level, 'Disk');
      // The level remembers what was selected.
      expect(selectedName, 'System');
      expect(focusLabel(), 'settings-detail/ring:0');
      await press(t, [kEscape]);
      expect(focusLabel(), startsWith('settings-list/storage'));
    });

    testWidgets('Apps: each profile\'s apps, then their generations', (
      t,
    ) async {
      await openStorage(t);
      await press(t, [kRight, kEnter]);
      expect(level, 'Apps');
      expect(selectedName, 'James');
      await press(t, [kEnter]);
      expect(level, 'James');
      expect(selectedName, 'Generation 9');
      await press(t, [kEscape, kEscape]);
      expect(level, 'Disk');
    });

    testWidgets('up and down leave the ring for the rows', (t) async {
      await openStorage(t);
      await press(t, [kDown]);
      expect(focusLabel(), 'settings-detail/measure:0');
      await press(t, [kDown, kDown, kDown]);
      expect(focusLabel(), 'settings-detail/auto:0');
      await press(t, [kUp, kUp, kUp, kUp]);
      expect(focusLabel(), 'settings-detail/ring:0');
    });

    testWidgets('sizes and the disk numbers beside the ring', (t) async {
      final h = await openStorage(t);
      final m = (await h.services.mockStorage.get())!;
      expect(selectedSize, storageSize(m.root.children.first.bytes));
      expect(find.text(storageSize(m.disk.totalBytes)), findsWidgets);
      expect(find.text(storageSize(m.disk.usedBytes)), findsOneWidget);
      expect(find.text(storageSize(m.disk.freeBytes)), findsWidgets);
      expect(find.text('Measured 2 hours ago.'), findsOneWidget);
    });

    testWidgets('nothing on the screen deletes or removes', (t) async {
      await openStorage(t);
      for (final word in ['Delete', 'Remove app', 'Uninstall', 'Remove']) {
        expect(find.textContaining(word), findsNothing);
      }
    });
  });

  group('who sees what', () {
    testWidgets('the own profile opens without a PIN', (t) async {
      final h = await openStorage(t);
      await press(t, [kRight, kRight, kEnter]);
      expect(find.text(_askPin), findsNothing);
      expect(level, 'James');
      expect(selectedName, 'Steam games');
      expect(h.services.mockStorage.treeLog, ['p1']);
      await press(t, [kEnter]);
      expect(level, 'Steam games');
      expect(selectedName, 'Disco Elysium');
      await press(t, [kEscape, kRight, kEnter]);
      expect(level, 'Videos');
      expect(selectedName, 'Holiday 2026');
    });

    testWidgets('another profile asks for the admin PIN; wrong asks again', (
      t,
    ) async {
      final h = await openStorage(t);
      await press(t, [kRight, kRight, kRight, kEnter]);
      expect(find.text('Open Sam'), findsOneWidget);
      expect(find.text(_askPin), findsOneWidget);
      await enterPin(t, '1357'); // Sam's own, not the admin's
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(find.text('Music'), findsNothing);
      await enterPin(t, '2468');
      expect(find.text(_askPin), findsNothing);
      expect(level, 'Sam');
      expect(h.services.mockStorage.treeLog.last, 'p3:pin');
      await press(t, [kRight]);
      expect(selectedName, 'Music');
    });

    testWidgets('Back on the PIN pad opens nothing', (t) async {
      final h = await openStorage(t);
      await press(t, [kRight, kRight, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(level, 'Disk');
      expect(selectedName, 'Sam');
      expect(h.services.mockStorage.treeLog, isEmpty);
    });

    testWidgets('a profile that is not the admin sees only totals', (t) async {
      final h = await openStorage(t, current: 'p3');
      // storage.get holds no names at all.
      final m = (await h.services.mockStorage.get())!;
      void noNames(StorageNode n) {
        expect(n.name, isNull);
        n.children.forEach(noNames);
      }

      noNames(m.root);
      // James's total is there, his folders are not.
      await press(t, [kRight, kRight]);
      expect(selectedName, 'James');
      expect(selectedSize, storageSize(mockHome('p1').bytes));
      await press(t, [kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      await press(t, [kEscape]);
      for (final name in ['Videos', 'Disco Elysium', 'Steam games']) {
        expect(find.text(name), findsNothing);
      }
      // Sam's own home opens directly.
      await press(t, [kRight, kEnter]);
      expect(level, 'Sam');
      expect(find.text(_askPin), findsNothing);
    });

    testWidgets('the guest opens its own home without a PIN', (t) async {
      await openStorage(t, current: 'guest');
      await press(t, [kLeft, kLeft, kLeft]);
      expect(selectedName, 'Guest');
      await press(t, [kEnter]);
      expect(find.text(_askPin), findsNothing);
      expect(level, 'Guest');
    });

    testWidgets('the guest\'s home asks the admin PIN of a profile', (t) async {
      await openStorage(t);
      await press(t, [kLeft, kLeft, kLeft, kEnter]);
      expect(find.text('Open Guest'), findsOneWidget);
      await enterPin(t, '2468');
      expect(level, 'Guest');
    });
  });

  group('clean-up', () {
    /// From the ring: down to the row, A: the clean-up dialog.
    Future<void> openCleanup(WidgetTester t, CleanupTarget target) => press(t, [
      kDown,
      kDown,
      if (target == CleanupTarget.profiles) kDown,
      kEnter,
    ]);

    String keepValue() {
      final m = find.byKey(const ValueKey('keep-value'));
      return (m.evaluate().single.widget as StepperMark).label;
    }

    testWidgets('the system: picker from the automatic setting, warning, '
        'estimate, PIN, job, freed', (t) async {
      final h = await openStorage(t);
      h.services.mockStorage.settings = const CleanupSettings(keepSystem: 3);
      // The setting is read when Storage opens: open it again.
      await press(t, [kEscape]);
      await press(t, [kUp, kDown, kRight]);
      await openCleanup(t, CleanupTarget.system);
      expect(find.text('Clean up the system'), findsWidgets);
      expect(keepValue(), '3');
      final m = (await h.services.mockStorage.get())!;
      String estimate(int keep) {
        final e = m.estimate(CleanupTarget.system, keep)!;
        return 'Frees about ${storageSize(e.bytes)}. Removes '
            '${e.generations} ${e.generations == 1 ? 'version' : 'versions'}.';
      }

      expect(find.text(estimate(3)), findsOneWidget);
      expect(find.byKey(const ValueKey('cleanup-warning')), findsNothing);
      await press(t, [kLeft]);
      expect(keepValue(), '2');
      expect(find.byKey(const ValueKey('cleanup-warning')), findsNothing);
      await press(t, [kLeft]);
      expect(keepValue(), '1');
      expect(
        find.text('No older version stays. You cannot roll back the system.'),
        findsOneWidget,
      );
      expect(find.text(estimate(1)), findsOneWidget);
      // Not below 1, not above 10.
      await press(t, [kLeft]);
      expect(keepValue(), '1');
      await press(t, List.filled(12, kRight));
      expect(keepValue(), '10');
      await press(t, List.filled(9, kLeft));
      // Clean up: the admin PIN.
      await press(t, [kDown, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '1111');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(h.services.mockJobs.started, isEmpty);
      await enterPin(t, '2468');
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.cleanupSystem);
      expect(find.text('Cleaning up the system'), findsOneWidget);
      h.services.mockJobs.progress(job.jobId, JobStage.cleaning);
      await t.pumpAndSettle();
      expect(find.text("Can't cancel now"), findsOneWidget);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      final freed = (m.estimate(CleanupTarget.system, 1)!.bytes * 0.94).round();
      expect(find.text('Freed ${storageSize(freed)}.'), findsOneWidget);
      await press(t, [kEnter]);
      expect(
        find.text('These numbers are from before the clean-up. Measure again.'),
        findsOneWidget,
      );
    });

    testWidgets('Back on the PIN pad starts nothing', (t) async {
      final h = await openStorage(t);
      await openCleanup(t, CleanupTarget.system);
      await press(t, [kDown, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      await press(t, [kEscape]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('Cancel in the dialog starts nothing', (t) async {
      final h = await openStorage(t);
      await openCleanup(t, CleanupTarget.profiles);
      await press(t, [kDown, kEnter]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('profiles: own warning, PIN, job, freed', (t) async {
      final h = await openStorage(t);
      await openCleanup(t, CleanupTarget.profiles);
      expect(find.text('Clean up profiles'), findsWidgets);
      expect(keepValue(), '5');
      await press(t, List.filled(4, kLeft));
      expect(
        find.text('No older apps stay. Profiles cannot roll back their apps.'),
        findsOneWidget,
      );
      await press(t, [kDown, kRight, kEnter]);
      await enterPin(t, '2468');
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.cleanupProfiles);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      final m = (await h.services.mockStorage.get())!;
      final freed = (m.estimate(CleanupTarget.profiles, 1)!.bytes * 0.94)
          .round();
      expect(find.text('Freed ${storageSize(freed)}.'), findsOneWidget);
      expect(h.services.mockStorage.appGenerations, 1);
    });
  });

  group('automatic clean-up', () {
    Future<void> openAuto(WidgetTester t) =>
        press(t, [kDown, kDown, kDown, kDown, kEnter]);

    testWidgets('values, the admin PIN, the job', (t) async {
      final h = await openStorage(t);
      expect(find.text('Every week'), findsOneWidget);
      await openAuto(t);
      expect(find.text('Automatic clean-up'), findsWidgets);
      // How often: monthly; system keeps 3; profiles keep 1 (a warning).
      await press(t, [kDown, kRight, kRight]);
      expect(find.text('Every month'), findsOneWidget);
      await press(t, [kDown, kLeft, kLeft]);
      await press(t, [kDown, kLeft, kLeft, kLeft, kLeft]);
      expect(
        find.text('No older apps stay. Profiles cannot roll back their apps.'),
        findsOneWidget,
      );
      await press(t, [kDown, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      await enterPin(t, '0000');
      expect(find.text('Wrong PIN.'), findsOneWidget);
      await enterPin(t, '2468');
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.cleanupSet);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      await press(t, [kEnter]);
      expect(
        h.services.mockStorage.settings,
        const CleanupSettings(
          frequency: CleanupFrequency.monthly,
          keepSystem: 3,
          keepProfiles: 1,
        ),
      );
      expect(find.text('Every month'), findsOneWidget);
    });

    testWidgets('off', (t) async {
      final h = await openStorage(t);
      await openAuto(t);
      await press(t, [kEnter]); // the switch
      await press(t, [kDown, kDown, kDown, kDown, kRight, kEnter]);
      await enterPin(t, '2468');
      h.services.mockJobs.finish(h.services.mockJobs.started.single.jobId);
      await t.pumpAndSettle();
      await press(t, [kEnter]);
      expect(h.services.mockStorage.settings.enable, isFalse);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Automatic clean-up'),
            matching: find.byType(SettingRow),
          ),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing changed: no PIN, no job', (t) async {
      final h = await openStorage(t);
      await openAuto(t);
      await press(t, [kDown, kDown, kDown, kDown, kRight, kEnter]);
      expect(find.text(_askPin), findsNothing);
      expect(h.services.mockJobs.started, isEmpty);
    });

    testWidgets('Back on the PIN pad keeps the setting', (t) async {
      final h = await openStorage(t);
      await openAuto(t);
      await press(t, [kDown, kRight, kDown, kDown, kDown, kRight, kEnter]);
      expect(find.text(_askPin), findsOneWidget);
      await press(t, [kEscape]);
      expect(h.services.mockJobs.started, isEmpty);
      expect(h.services.mockStorage.settings, const CleanupSettings());
    });
  });

  group('measuring', () {
    testWidgets('no measurement yet: measure, progress, then the ring', (
      t,
    ) async {
      final h = await openStorage(t, measured: false);
      expect(find.text('The disk is not measured yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('storage-ring')), findsNothing);
      expect(focusLabel(), 'settings-detail/measure:0');
      await press(t, [kEnter]);
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.storageMeasure);
      expect(find.text('Measuring the disk'), findsOneWidget);
      h.services.mockJobs.progress(job.jobId, JobStage.measuring, percent: 40);
      await t.pumpAndSettle();
      expect(find.text('  40%'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      h.services.mockJobs.finish(job.jobId);
      await t.pumpAndSettle();
      expect(find.text('Measured.'), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.byKey(const ValueKey('storage-ring')), findsOneWidget);
      expect(find.text('Measured just now.'), findsOneWidget);
    });

    testWidgets('measure again: a job; cancelled keeps the old one', (t) async {
      final h = await openStorage(t);
      expect(find.text('Measured 2 hours ago.'), findsOneWidget);
      await press(t, [kDown, kEnter]);
      final job = h.services.mockJobs.started.single;
      expect(job.kind, JobKind.storageMeasure);
      h.services.mockJobs.progress(job.jobId, JobStage.measuring, percent: 10);
      await t.pumpAndSettle();
      await press(t, [kEnter]); // Cancel
      expect(find.text('Cancelled'), findsOneWidget);
      await press(t, [kEnter]);
      expect(find.text('Measured 2 hours ago.'), findsOneWidget);
    });

    test('the age of a measurement', () {
      final now = DateTime(2026, 10, 6, 20, 30);
      String ago(Duration d) => measuredAgo(now.subtract(d), now);
      expect(ago(const Duration(seconds: 20)), 'Measured just now.');
      expect(ago(const Duration(minutes: 1)), 'Measured 1 minute ago.');
      expect(ago(const Duration(minutes: 59)), 'Measured 59 minutes ago.');
      expect(ago(const Duration(hours: 5)), 'Measured 5 hours ago.');
      expect(ago(const Duration(days: 1, hours: 2)), 'Measured 1 day ago.');
      expect(ago(const Duration(days: 9)), 'Measured 9 days ago.');
    });

    test('sizes', () {
      expect(storageSize(0), '0 MB');
      expect(storageSize(50000), '0.1 MB');
      expect(storageSize(12500000), '12.5 MB');
      expect(storageSize(800000000), '800 MB');
      expect(storageSize(9400000000), '9.4 GB');
      expect(storageSize(312000000000), '312 GB');
      expect(storageSize(2000000000000), '2.0 TB');
    });
  });
}
