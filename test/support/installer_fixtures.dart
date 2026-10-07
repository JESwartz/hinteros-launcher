// Output of the tools the installer reads, as fixtures.

/// `lsblk --json -b -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,RM,MOUNTPOINTS` on a
/// machine booted from a USB stick: an NVMe disk, a SATA disk, the stick
/// (with a partition mounted), a USB drive, an eMMC that is too small, and
/// the devices that must not appear (loop, rom, zram).
const lsblkFixture = r'''
{
  "blockdevices": [
    {"name":"loop0","path":"/dev/loop0","size":1073741824,"model":null,"tran":null,"type":"loop","rm":false,"mountpoints":["/nix/.ro-store"]},
    {"name":"sr0","path":"/dev/sr0","size":1073741824,"model":"DVD","tran":"sata","type":"rom","rm":true,"mountpoints":[null]},
    {"name":"zram0","path":"/dev/zram0","size":8589934592,"model":null,"tran":null,"type":"disk","rm":false,"mountpoints":["[SWAP]"]},
    {"name":"nvme0n1","path":"/dev/nvme0n1","size":512110190592,"model":"Example NVMe 512GB    ","tran":"nvme","type":"disk","rm":false,"mountpoints":[null],
      "children":[
        {"name":"nvme0n1p1","path":"/dev/nvme0n1p1","size":1073741824,"model":null,"tran":null,"type":"part","rm":false,"mountpoints":["/mnt/boot"]},
        {"name":"nvme0n1p2","path":"/dev/nvme0n1p2","size":511036448768,"model":null,"tran":null,"type":"part","rm":false,"mountpoints":["/mnt"]}
      ]},
    {"name":"sda","path":"/dev/sda","size":1000204886016,"model":"Example SATA SSD 1TB","tran":"sata","type":"disk","rm":false,"mountpoints":[null]},
    {"name":"sdb","path":"/dev/sdb","size":34359738368,"model":"Example USB Stick","tran":"usb","type":"disk","rm":true,"mountpoints":[null],
      "children":[
        {"name":"sdb1","path":"/dev/sdb1","size":3800000000,"model":null,"tran":null,"type":"part","rm":true,"mountpoints":["/iso"]}
      ]},
    {"name":"sdc","path":"/dev/sdc","size":2000398934016,"model":"Example USB Drive 2TB","tran":"usb","type":"disk","rm":true,"mountpoints":[null]},
    {"name":"mmcblk0","path":"/dev/mmcblk0","size":8589934592,"model":null,"tran":null,"type":"disk","rm":false,"mountpoints":[null]}
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

/// A catalog index (design/catalog.md, `indexVersion` 1) as the ISO would
/// carry it: Steam and Plex with their vendor terms. Unknown ids, a removed
/// app and an unfree app without terms are in it to be dropped.
// TODO(M8): replace with the real index once the catalog repo ships `terms`.
const catalogIndexFixture = r'''
{ "indexVersion": 1, "apps": [
  { "id": "jellyfin", "name": "Jellyfin", "summary": "Media player", "category": "video", "sizeMiB": 280, "featured": true, "preinstalled": true, "status": "available", "free": true },
  { "id": "youtube", "name": "YouTube", "summary": "The site", "category": "video", "sizeMiB": 1, "status": "available", "free": true },
  { "id": "retroarch", "name": "RetroArch", "summary": "Not an installer app", "category": "games", "sizeMiB": 220, "status": "available", "free": true },
  { "id": "crunchyroll", "name": "Crunchyroll", "status": "removed", "statusReason": "gone" },
  { "id": "firefox", "name": "Firefox", "summary": "Browser", "category": "web", "sizeMiB": 90, "status": "available", "free": true },
  { "id": "steam", "name": "Steam", "summary": "Games", "category": "games", "sizeMiB": 1000, "status": "available", "free": false,
    "terms": {"vendor": "Example Games Co.", "version": "2026-03", "sourceUrl": "https://store.example/steam/terms", "text": "STEAM TERMS TEXT"} },
  { "id": "plex-htpc", "name": "Plex", "summary": "Plex on the TV", "category": "video", "sizeMiB": 300, "status": "available", "free": false,
    "terms": {"vendor": "Example Media Inc.", "version": "2026-01", "sourceUrl": "https://media.example/terms", "text": "PLEX TERMS TEXT"} },
  { "id": "moonlight", "name": "Moonlight", "summary": "Stream games", "category": "games", "sizeMiB": 150, "status": "available", "free": true },
  { "id": "unlisted-unfree", "name": "X", "status": "available", "free": false }
] }
''';
