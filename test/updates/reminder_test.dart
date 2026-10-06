import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/system/mock_system.dart';
import 'package:hinteros_launcher/src/system/models.dart';
import 'package:hinteros_launcher/src/updates/reminder.dart';

void main() {
  test('a security notice is due at startup and on every return', () async {
    final jobs = MockJobs();
    final ups = MockUpdates(jobs)..nextAvailable = mockSecurityUpdate();
    final r = UpdateReminders(ups);
    expect(r.securityNoticeDue(), isFalse, reason: 'nothing known yet');
    await r.start();
    expect(r.behind, isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(r.securityNoticeDue(), isTrue);
    expect(jobs.started, isEmpty, reason: 'never installs by itself');
    r.dispose();
  });

  test('an ordinary update never asks for the full-screen notice', () async {
    final ups = MockUpdates(MockJobs())..nextAvailable = mockOrdinaryUpdate();
    final r = UpdateReminders(ups);
    await r.start();
    expect(r.behind, isTrue);
    expect(r.securityNoticeDue(), isFalse);
    r.dispose();
  });

  test('an unreachable update server is not an error at startup', () async {
    final ups = MockUpdates(MockJobs())
      ..failCheckWith = const SystemException(
        SystemErrorKind.updateUnreachable,
        'x',
      );
    final r = UpdateReminders(ups);
    await r.start();
    expect(r.behind, isFalse);
    r.dispose();
  });

  test('up to date: no reminder', () async {
    final r = UpdateReminders(MockUpdates(MockJobs()));
    await r.start();
    expect(r.behind, isFalse);
    r.dispose();
  });
}
