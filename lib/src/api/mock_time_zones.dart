/// Time zones of the mocks (session API 0.16 `system.time_zone.*`): a
/// realistic part of tzdata's `zone1970.tab` plus `UTC`, with the offsets of
/// early October 2026 (northern daylight saving time still on, the southern
/// one begun) and the next offset change. Shared by the wire mock
/// ([MockSystemRelay]) and the in-process one (`MockTimeZone`).
library;

/// One zone: its offset now and its standard offset, in minutes, and the
/// next offset change (Unix seconds), if any.
typedef MockZone = ({String zone, int offset, int standard, int? until});

MockZone _z(String zone, int offset, int standard, [int? until]) =>
    (zone: zone, offset: offset, standard: standard, until: until);

// The next changes: the US on 2026-11-01 at 02:00 local, the EU on
// 2026-10-25 at 01:00 UTC, the southern zones in April 2027.
const _usEast = 1793512800,
    _usCentral = 1793516400,
    _usMountain = 1793520000,
    _usPacific = 1793523600,
    _alaska = 1793527200,
    _atlanticCa = 1793509200,
    _newfoundland = 1793507400,
    _eu = 1792890000,
    _israel = 1792882800,
    _egypt = 1793307600,
    _chile = 1806807600,
    _auEast = 1806768000,
    _auSouth = 1806769800,
    _lordHowe = 1806764400,
    _nz = 1806760800;

/// Sorted by name, like `time_zone.list`.
final List<MockZone> mockTimeZones = [
  _z('Africa/Abidjan', 0, 0),
  _z('Africa/Cairo', 180, 120, _egypt),
  _z('Africa/Johannesburg', 120, 120),
  _z('Africa/Lagos', 60, 60),
  _z('Africa/Nairobi', 180, 180),
  _z('America/Anchorage', -480, -540, _alaska),
  _z('America/Argentina/Buenos_Aires', -180, -180),
  _z('America/Bogota', -300, -300),
  _z('America/Caracas', -240, -240),
  _z('America/Chicago', -300, -360, _usCentral),
  _z('America/Denver', -360, -420, _usMountain),
  _z('America/Halifax', -180, -240, _atlanticCa),
  _z('America/Lima', -300, -300),
  _z('America/Los_Angeles', -420, -480, _usPacific),
  _z('America/Mexico_City', -360, -360),
  _z('America/New_York', -240, -300, _usEast),
  _z('America/Phoenix', -420, -420),
  _z('America/Santiago', -180, -240, _chile),
  _z('America/Sao_Paulo', -180, -180),
  _z('America/St_Johns', -150, -210, _newfoundland),
  _z('America/Toronto', -240, -300, _usEast),
  _z('America/Vancouver', -420, -480, _usPacific),
  _z('Antarctica/Casey', 480, 480),
  _z('Antarctica/Troll', 120, 0, _eu),
  _z('Asia/Bangkok', 420, 420),
  _z('Asia/Dhaka', 360, 360),
  _z('Asia/Dubai', 240, 240),
  _z('Asia/Hong_Kong', 480, 480),
  _z('Asia/Jakarta', 420, 420),
  _z('Asia/Jerusalem', 180, 120, _israel),
  _z('Asia/Kabul', 270, 270),
  _z('Asia/Karachi', 300, 300),
  _z('Asia/Kathmandu', 345, 345),
  _z('Asia/Kolkata', 330, 330),
  _z('Asia/Manila', 480, 480),
  _z('Asia/Seoul', 540, 540),
  _z('Asia/Shanghai', 480, 480),
  _z('Asia/Singapore', 480, 480),
  _z('Asia/Tehran', 210, 210),
  _z('Asia/Tokyo', 540, 540),
  _z('Asia/Yangon', 390, 390),
  _z('Atlantic/Azores', 0, -60, _eu),
  _z('Atlantic/Canary', 60, 0, _eu),
  _z('Atlantic/Cape_Verde', -60, -60),
  _z('Atlantic/South_Georgia', -120, -120),
  _z('Australia/Adelaide', 630, 570, _auSouth),
  _z('Australia/Brisbane', 600, 600),
  _z('Australia/Darwin', 570, 570),
  _z('Australia/Eucla', 525, 525),
  _z('Australia/Lord_Howe', 660, 630, _lordHowe),
  _z('Australia/Perth', 480, 480),
  _z('Australia/Sydney', 660, 600, _auEast),
  _z('Europe/Berlin', 120, 60, _eu),
  _z('Europe/Helsinki', 180, 120, _eu),
  _z('Europe/Istanbul', 180, 180),
  _z('Europe/Kyiv', 180, 120, _eu),
  _z('Europe/Lisbon', 60, 0, _eu),
  _z('Europe/London', 60, 0, _eu),
  _z('Europe/Madrid', 120, 60, _eu),
  _z('Europe/Moscow', 180, 180),
  _z('Europe/Paris', 120, 60, _eu),
  _z('Europe/Rome', 120, 60, _eu),
  _z('Europe/Warsaw', 120, 60, _eu),
  _z('Indian/Chagos', 360, 360),
  _z('Indian/Maldives', 300, 300),
  _z('Indian/Mauritius', 240, 240),
  _z('Pacific/Auckland', 780, 720, _nz),
  _z('Pacific/Chatham', 825, 765, _nz),
  _z('Pacific/Fiji', 720, 720),
  _z('Pacific/Guam', 600, 600),
  _z('Pacific/Honolulu', -600, -600),
  _z('Pacific/Kiritimati', 840, 840),
  _z('Pacific/Marquesas', -570, -570),
  _z('Pacific/Pago_Pago', -660, -660),
  _z('Pacific/Tongatapu', 780, 780),
  _z('UTC', 0, 0),
];

MockZone? mockTimeZone(String zone) =>
    mockTimeZones.where((z) => z.zone == zone).firstOrNull;
