/// The browser has no evdev devices: [readAbsRange] gives null, as on any
/// failure of the real one (`evdev_ioctl.dart`, which needs `dart:ffi`).
/// Only the browser demo (`lib/web_main.dart`) compiles this, through the
/// profile picker.
library;

/// Always null in the browser.
(int, int)? readAbsRange(String path, int abs) => null;
