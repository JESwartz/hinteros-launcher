import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';

void main() {
  group('plan JSON', () {
    test('keepData: only what the backend takes', () {
      const plan = InstallPlan.keepData(
        disk: '/dev/nvme0n1',
        diskSeq: 1,
        hostname: 'den',
        adminUser: 'alex',
        channel: InstallChannel.beta,
      );
      expect(plan.toJson(), {
        'disk': '/dev/nvme0n1',
        'diskSeq': 1,
        'keepData': true,
        'hostname': 'den',
        'admin': {'user': 'alex'},
        'ssh': {'enable': false},
        'channel': 'beta',
        'network': 'auto',
      });
      const newPassword = InstallPlan.keepData(
        disk: '/dev/nvme0n1',
        diskSeq: 1,
        hostname: 'den',
        adminUser: 'alex',
        adminPassword: 'change-me-now',
        ssh: true,
      );
      expect(newPassword.toJson()['admin'], {
        'user': 'alex',
        'password': 'change-me-now',
      });
      expect(newPassword.toJson()['ssh'], {'enable': true});
      expect(newPassword.toString(), isNot(contains('change-me-now')));
      const wifi = InstallPlan.keepData(
        disk: '/dev/nvme0n1',
        diskSeq: 1,
        hostname: 'den',
        adminUser: 'alex',
        network: PlanNetwork.offline,
        wifiSsid: 'Home',
        wifiPsk: 'secret',
      );
      expect(wifi.toJson()['wifi'], {'ssid': 'Home', 'psk': 'secret'});
      expect(wifi.toJson()['network'], 'offline');
      expect(wifi.toString(), isNot(contains('secret')));
    });

    test('a plan without keepData does not name it', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'hinteros',
        adminUser: 'james',
        adminPassword: 'change-me-now',
      );
      expect(plan.keepData, isFalse);
      expect(plan.toJson().containsKey('keepData'), isFalse);
    });

    test('matches the backend format field for field', () {
      const plan = InstallPlan(
        disk: '/dev/nvme0n1',
        diskSeq: 1,
        hostname: 'hinteros',
        adminUser: 'james',
        adminPassword: 'change-me-now',
        apps: ['youtube', 'firefox'],
      );
      // The example of the system repo's README ("Installer"), plus the
      // fields the UI always sends (base, network).
      expect(plan.toJson(), {
        'disk': '/dev/nvme0n1',
        'diskSeq': 1,
        'hostname': 'hinteros',
        'admin': {'user': 'james', 'password': 'change-me-now'},
        'ssh': {'enable': false},
        'channel': 'stable',
        'base': 'unstable',
        'network': 'auto',
        'apps': ['youtube', 'firefox'],
        'acceptedTerms': <String, String>{},
      });
    });

    test('accepted terms are id -> version', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'box',
        adminUser: 'a',
        adminPassword: 'password1',
        apps: ['steam', 'youtube'],
        acceptedTerms: {'steam': '2026-09-10'},
      );
      expect(plan.toJson()['acceptedTerms'], {'steam': '2026-09-10'});
      expect(
        jsonDecode(utf8.decode(plan.encode())),
        containsPair('acceptedTerms', {'steam': '2026-09-10'}),
      );
    });

    test('only fields the backend knows', () {
      const known = {
        'disk',
        'diskSeq',
        'hostname',
        'admin',
        'ssh',
        'channel',
        'base',
        'network',
        'apps',
        'acceptedTerms',
        'wifi',
      };
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'box',
        adminUser: 'a',
        adminPassword: 'password1',
        ssh: true,
        channel: InstallChannel.beta,
        network: PlanNetwork.online,
        apps: ['steam'],
        wifiSsid: 'Living Room',
        wifiPsk: 'secret psk',
      );
      final j = plan.toJson();
      expect(known.containsAll(j.keys), isTrue);
      expect(j['ssh'], {'enable': true});
      expect(j['channel'], 'beta');
      expect(j['network'], 'online');
      expect(j['wifi'], {'ssid': 'Living Room', 'psk': 'secret psk'});
    });

    test('an open Wi-Fi network has no psk', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'box',
        adminUser: 'a',
        adminPassword: 'password1',
        wifiSsid: 'Cafe',
      );
      expect(plan.toJson()['wifi'], {'ssid': 'Cafe'});
    });

    test('encodes as one line of UTF-8 JSON, round-trips', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'box',
        adminUser: 'a',
        adminPassword: 'pässword "with" \\ quotes',
      );
      final text = utf8.decode(plan.encode());
      expect(text.contains('\n'), isFalse);
      expect(jsonDecode(text), plan.toJson());
    });

    test('toString never shows the password', () {
      const plan = InstallPlan(
        disk: '/dev/sda',
        diskSeq: 1,
        hostname: 'box',
        adminUser: 'a',
        adminPassword: 'hunter2hunter2',
        wifiSsid: 'x',
        wifiPsk: 'wifi-secret',
      );
      expect('$plan', isNot(contains('hunter2')));
      expect('$plan', isNot(contains('wifi-secret')));
    });
  });

  group('checks mirror the backend', () {
    test('user names', () {
      expect(PlanChecks.username('james'), isNull);
      expect(PlanChecks.username('_svc-1'), isNull);
      expect(PlanChecks.username(''), isNotNull);
      expect(PlanChecks.username('James'), isNotNull);
      expect(PlanChecks.username('1abc'), isNotNull);
      expect(PlanChecks.username('a' * 33), isNotNull);
      for (final r in ['root', 'hinteros', 'nobody', 'systemd-x', 'nixbld3']) {
        expect(PlanChecks.username(r), contains('reserved'), reason: r);
      }
    });

    test('host names', () {
      expect(PlanChecks.hostname('hinteros'), isNull);
      expect(PlanChecks.hostname('living-room-1'), isNull);
      expect(PlanChecks.hostname('-bad'), isNotNull);
      expect(PlanChecks.hostname('bad-'), isNotNull);
      expect(PlanChecks.hostname('Upper'), isNotNull);
      expect(PlanChecks.hostname(''), isNotNull);
      expect(PlanChecks.hostname('a' * 64), isNotNull);
    });

    test('passwords', () {
      expect(PlanChecks.password('longenough'), isNull);
      expect(PlanChecks.password(''), isNotNull);
      expect(PlanChecks.password('short'), isNotNull);
      expect(PlanChecks.password('line\nbreak!!'), isNotNull);
    });
  });
}
