import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/installer/backend.dart';
import 'package:hinteros_launcher/src/installer/parsers.dart';
import 'package:hinteros_launcher/src/installer/plan.dart';

import '../support/installer_fixtures.dart';

void main() {
  group('--list-disks', () {
    String listing(String existing, {String extra = ''}) =>
        '{"blockdevices":[{"name":"vdc","path":"/dev/vdc","size":34359738368,'
        '"model":null,"tran":null,"type":"disk","rm":false,'
        '"mountpoints":[null],"disk-seq":3,$extra"existing":$existing}]}';

    test('an install that can be kept', () {
      final d = parseLsblk(
        listing(
          '{"profiles":1,"schemaOk":true,"version":"0.7.0","channel":"beta"}',
        ),
      ).single;
      expect(d.existing!.schemaOk, isTrue);
      expect(d.existing!.version, '0.7.0');
      expect(d.existing!.channel, InstallChannel.beta);
      expect(d.canKeep, isTrue);
    });

    test('no version, and an install that cannot be kept', () {
      final d = parseLsblk(listing('{"profiles":2,"schemaOk":false}')).single;
      expect(d.existing!.schemaOk, isFalse);
      expect(d.existing!.channel, isNull);
      expect(d.existing!.version, isNull);
      expect(d.canKeep, isFalse);
    });

    test('null, odd values and plain lsblk: nothing to keep', () {
      expect(parseLsblk(listing('null')).single.existing, isNull);
      expect(parseLsblk(listing('"yes"')).single.existing, isNull);
      expect(parseLsblk(listing('{"profiles":1}')).single.canKeep, isFalse);
      expect(parseLsblk(lsblkFixture).any((d) => d.existing != null), isFalse);
    });

    test('a disk that cannot be chosen cannot be kept', () {
      final d = parseLsblk(
        listing(
          '{"schemaOk":true}',
          extra: '"children":[{"name":"vdc1","mountpoints":["/iso"]}],',
        ),
      ).single;
      expect(d.existing, isNotNull);
      expect(d.canKeep, isFalse);
    });

    test('a mount under /mnt is noted, and does not make it in use', () {
      final d = parseLsblk(lsblkFixture).first;
      expect(d.mountpoints, isEmpty);
      expect(d.installLeftover, isTrue);
      expect(parseLsblk(lsblkFixture)[1].installLeftover, isFalse);
    });
  });

  group('versionNewer', () {
    test('by the numbers, not as text', () {
      expect(versionNewer('0.10.0', '0.9.0'), isTrue);
      expect(versionNewer('1.0.0', '0.99.99'), isTrue);
      expect(versionNewer('0.7.1', '0.7.0'), isTrue);
      expect(versionNewer('0.7.0', '0.7.1'), isFalse);
      expect(versionNewer('0.7.0', '0.7.0'), isFalse);
    });

    test('a suffix comes before its release', () {
      expect(versionNewer('1.0.0', '1.0.0-rc.1'), isTrue);
      expect(versionNewer('1.0.0-rc.1', '1.0.0'), isFalse);
      expect(versionNewer('1.0.0-rc.10', '1.0.0-rc.9'), isTrue);
      expect(versionNewer('1.0.0-rc.1', '1.0.0-beta.2'), isTrue);
      expect(versionNewer('1.0.0-rc.1.1', '1.0.0-rc.1'), isTrue);
      expect(versionNewer('1.0.0-rc.1', '1.0.0-rc.1'), isFalse);
    });

    test('what is not a release is never newer', () {
      expect(versionNewer('1a2b3c4d5e6f', '0.7.0'), isFalse);
      expect(versionNewer('0.7.0', '1a2b3c4d5e6f'), isFalse);
      expect(versionNewer('', '0.7.0'), isFalse);
    });
  });

  group('lsblk', () {
    test('lists whole disks only, with the reasons for hiding some', () {
      final disks = parseLsblk(lsblkFixture);
      expect(
        [for (final d in disks) d.name],
        ['nvme0n1', 'sda', 'sdb', 'sdc', 'mmcblk0'],
        reason: 'no loop, rom or zram devices, no partitions',
      );
      final byName = {for (final d in disks) d.name: d};

      final nvme = byName['nvme0n1']!;
      expect(nvme.path, '/dev/nvme0n1');
      expect(nvme.sizeBytes, 512110190592);
      expect(nvme.diskSeq, 1);
      expect(nvme.title, 'Example NVMe 512GB');
      expect(nvme.sizeLabel, '512 GB');
      expect(nvme.usable, isTrue);
      expect(nvme.mountpoints, isEmpty, reason: '/mnt leftovers do not count');

      // In use: a partition is mounted (the ISO stick), and it is removable.
      final stick = byName['sdb']!;
      expect(stick.mountpoints, ['/iso']);
      expect(stick.unusableReason, contains('In use'));

      expect(byName['sdc']!.removable, isTrue);
      expect(byName['sdc']!.unusableReason, contains('Removable'));
      expect(byName['mmcblk0']!.unusableReason, contains('Too small'));
      expect(byName['sda']!.sizeLabel, '1.0 TB');
      expect(byName['sda']!.usable, isTrue);
    });

    test('old lsblk: sizes and flags as strings', () {
      final d = parseLsblk(
        '{"blockdevices":[{"name":"sda","path":"/dev/sda","size":"34359738368",'
        '"model":null,"tran":"sata","type":"disk","rm":"0","mountpoints":[null],'
        '"disk-seq":"7"}]}',
      ).single;
      expect(d.sizeBytes, 34359738368);
      expect(d.diskSeq, 7);
      expect(d.removable, isFalse);
      expect(d.title, 'sda');
      expect(d.usable, isTrue);
    });

    test('without a disk sequence number a disk cannot be chosen', () {
      final d = parseLsblk(
        '{"blockdevices":[{"name":"sda","path":"/dev/sda","size":34359738368,'
        '"model":null,"tran":"sata","type":"disk","rm":false,"mountpoints":[null]}]}',
      ).single;
      expect(d.diskSeq, isNull);
      expect(d.unusableReason, 'Cannot identify this disk.');
    });

    test('exactly 16 GiB is enough, one byte less is not', () {
      DiskInfo disk(int size) =>
          DiskInfo(path: '/dev/x', name: 'x', sizeBytes: size, diskSeq: 1);
      expect(disk(16 * 1024 * 1024 * 1024).usable, isTrue);
      expect(disk(16 * 1024 * 1024 * 1024 - 1).usable, isFalse);
    });

    test('not lsblk output is an error', () {
      expect(() => parseLsblk('hello'), throwsFormatException);
      expect(() => parseLsblk('{"x":1}'), throwsFormatException);
    });

    test('the arguments are the documented ones, no shell string', () {
      expect(lsblkArgs, [
        '--json',
        '-b',
        '-o',
        'NAME,PATH,SIZE,MODEL,TRAN,TYPE,RM,MOUNTPOINTS,DISK-SEQ',
      ]);
    });
  });

  group('nmcli terse output', () {
    test('splits on colons, honouring backslash escapes', () {
      expect(splitTerse('a:b:c'), ['a', 'b', 'c']);
      expect(splitTerse(r'*:My\:Net:77:WPA2'), ['*', 'My:Net', '77', 'WPA2']);
      expect(splitTerse(r'a\\b:c'), [r'a\b', 'c']);
      expect(splitTerse(':'), ['', '']);
      expect(splitTerse(''), ['']);
      expect(splitTerse(r'trailing\'), [r'trailing\']);
    });

    test('Wi-Fi list: strongest first, one per name, odd ones marked', () {
      final aps = parseWifiList(wifiFixture);
      expect(
        [for (final a in aps) a.ssid],
        ['Living Room', 'My:Net', 'Cafe Guest', 'Office', '-oops', 'Old WEP'],
      );
      final by = {for (final a in aps) a.ssid: a};
      expect(by['Living Room']!.signal, 82, reason: 'the stronger duplicate');
      expect(by['Living Room']!.inUse, isTrue);
      expect(by['Living Room']!.secured, isTrue);
      expect(by['Cafe Guest']!.secured, isFalse);
      expect(by['Office']!.supported, isFalse, reason: '802.1X');
      expect(by['Old WEP']!.supported, isFalse);
      expect(
        by['-oops']!.supported,
        isFalse,
        reason: 'could pass for an option',
      );
      expect(by['My:Net']!.supported, isTrue);
      expect(by['Living Room']!.bars, 4);
      expect(by['Cafe Guest']!.bars, 2);
    });

    test('Wi-Fi list ignores hidden names, control characters and junk', () {
      expect(parseWifiList(':::\nnot a record\n *:\u0007x:50:WPA2\n'), isEmpty);
    });

    test('network state', () {
      final n = parseNetwork(
        'ethernet:connected:Wired connection 1\nwifi:disconnected:\nloopback:unmanaged:\n',
        reachable: true,
      );
      expect(n.wiredConnected, isTrue);
      expect(n.wifiAvailable, isTrue);
      expect(n.wifiSsid, isNull);
      expect(n.online, isTrue);

      final w = parseNetwork(r'wifi:connected:Home\: 5G', reachable: false);
      expect(w.wifiSsid, 'Home: 5G');
      expect(w.online, isFalse, reason: 'probe failed');

      final ext = parseNetwork(
        'ethernet:connected (externally):Wired\nwifi:connecting (getting IP configuration):Home\n',
        reachable: true,
      );
      expect(ext.wiredConnected, isTrue);
      expect(ext.wifiSsid, isNull, reason: 'still connecting');

      final none = parseNetwork('wifi:unavailable:\n', reachable: false);
      expect(none.online, isFalse);
      expect(none.wifiAvailable, isTrue);

      // Online only with a link and a working probe.
      expect(
        parseNetwork('ethernet:connected:x', reachable: true).online,
        isTrue,
      );
      expect(parseNetwork('ethernet:connected:x').online, isFalse);
      expect(
        parseNetwork('ethernet:unavailable:', reachable: true).online,
        isFalse,
        reason: 'no link, no online',
      );
      expect(parseNetwork('', reachable: true).online, isFalse);
    });

    test('network state: a connection coming up', () {
      final c = parseNetwork(
        'ethernet:connecting (getting IP configuration):Wired connection 1\nwifi:disconnected:\n',
        reachable: true,
      );
      expect(c.connecting, isTrue);
      expect(c.linkUp, isFalse);
      expect(c.online, isFalse);
      expect(c.pending, isTrue);

      // A cable just plugged in: disconnected, not yet "unavailable".
      final p = parseNetwork('ethernet:disconnected:\nwifi:disconnected:\n');
      expect(p.cableWaiting, isTrue);
      expect(p.connecting, isFalse);
      expect(p.pending, isTrue);

      // No cable, only an idle Wi-Fi adapter: nothing is coming.
      final n = parseNetwork('ethernet:unavailable:\nwifi:disconnected:\n');
      expect(n.pending, isFalse);

      final done = parseNetwork(
        'ethernet:connected:Wired\nwifi:connecting:Home\n',
        reachable: true,
      );
      expect(done.pending, isFalse, reason: 'already connected');
      expect(done.connecting, isTrue);
      expect(done.withOnline(false).connecting, isTrue);
    });
  });
}
