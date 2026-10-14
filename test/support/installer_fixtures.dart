// Output of the tools the installer reads, as fixtures.

/// `lsblk --json -b -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,RM,MOUNTPOINTS,DISK-SEQ` on a
/// machine booted from a USB stick: an NVMe disk, a SATA disk, the stick
/// (with a partition mounted), a USB drive, an eMMC that is too small, and
/// the devices that must not appear (loop, rom, zram).
const lsblkFixture = r'''
{
  "blockdevices": [
    {"name":"loop0","disk-seq":9,"path":"/dev/loop0","size":1073741824,"model":null,"tran":null,"type":"loop","rm":false,"mountpoints":["/nix/.ro-store"]},
    {"name":"sr0","disk-seq":8,"path":"/dev/sr0","size":1073741824,"model":"DVD","tran":"sata","type":"rom","rm":true,"mountpoints":[null]},
    {"name":"zram0","disk-seq":7,"path":"/dev/zram0","size":8589934592,"model":null,"tran":null,"type":"disk","rm":false,"mountpoints":["[SWAP]"]},
    {"name":"nvme0n1","disk-seq":1,"path":"/dev/nvme0n1","size":512110190592,"model":"Example NVMe 512GB    ","tran":"nvme","type":"disk","rm":false,"mountpoints":[null],
      "children":[
        {"name":"nvme0n1p1","path":"/dev/nvme0n1p1","size":1073741824,"model":null,"tran":null,"type":"part","rm":false,"mountpoints":["/mnt/boot"]},
        {"name":"nvme0n1p2","path":"/dev/nvme0n1p2","size":511036448768,"model":null,"tran":null,"type":"part","rm":false,"mountpoints":["/mnt"]}
      ]},
    {"name":"sda","disk-seq":2,"path":"/dev/sda","size":1000204886016,"model":"Example SATA SSD 1TB","tran":"sata","type":"disk","rm":false,"mountpoints":[null]},
    {"name":"sdb","disk-seq":4,"path":"/dev/sdb","size":34359738368,"model":"Example USB Stick","tran":"usb","type":"disk","rm":true,"mountpoints":[null],
      "children":[
        {"name":"sdb1","path":"/dev/sdb1","size":3800000000,"model":null,"tran":null,"type":"part","rm":true,"mountpoints":["/iso"]}
      ]},
    {"name":"sdc","disk-seq":5,"path":"/dev/sdc","size":2000398934016,"model":"Example USB Drive 2TB","tran":"usb","type":"disk","rm":true,"mountpoints":[null]},
    {"name":"mmcblk0","disk-seq":3,"path":"/dev/mmcblk0","size":8589934592,"model":null,"tran":null,"type":"disk","rm":false,"mountpoints":[null]}
  ]
}
''';

/// `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list`.
const wifiFixture = r'''
*:Living Room:78:WPA2
 :Living Room:82:WPA2
 :My\:Net:60:WPA1 WPA2
 :Cafe Guest:33:
 :Office:20:WPA2 802.1X
 ::15:WPA2
 :-oops:12:WPA2
 :Old WEP:5:WEP
''';

/// The catalog index as the catalog repo's `index` package generates it
/// (format 2) with placeholder terms text: `catalog.json` and `terms/`.
const catalogFixtureDir = 'test/fixtures/catalog';
