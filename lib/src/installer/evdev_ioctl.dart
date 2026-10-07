/// `EVIOCGABS`: the minimum and maximum an absolute axis of an evdev device
/// reports. Dart has no ioctl, so this calls libc through `dart:ffi`; any
/// failure (no permission, not Linux) gives null and the caller assumes a
/// typical Xbox stick range.
library;

import 'dart:ffi';

typedef _Open = Int32 Function(Pointer<Uint8>, Int32);
typedef _OpenD = int Function(Pointer<Uint8>, int);
typedef _Ioctl = Int32 Function(Int32, UnsignedLong, Pointer<Uint8>);
typedef _IoctlD = int Function(int, int, Pointer<Uint8>);
typedef _Close = Int32 Function(Int32);
typedef _CloseD = int Function(int);
typedef _Calloc = Pointer<Uint8> Function(UnsignedLong, UnsignedLong);
typedef _CallocD = Pointer<Uint8> Function(int, int);
typedef _Free = Void Function(Pointer<Uint8>);
typedef _FreeD = void Function(Pointer<Uint8>);

const _oRdonly = 0;
const _oNonblock = 0x800;
const _oCloexec = 0x80000;

/// `struct input_absinfo` is six 32-bit ints: value, minimum, maximum, ...
const _absInfoSize = 24;

/// `_IOR('E', 0x40 + abs, struct input_absinfo)`.
int eviocgabs(int abs) =>
    (2 << 30) | (_absInfoSize << 16) | (0x45 << 8) | (0x40 + abs);

/// `(min, max)` of axis [abs] of the device node [path], or null. Only opens
/// the node read-only, never grabs it.
(int, int)? readAbsRange(String path, int abs) {
  try {
    final libc = DynamicLibrary.process();
    final open = libc.lookupFunction<_Open, _OpenD>('open');
    final ioctl = libc.lookupFunction<_Ioctl, _IoctlD>('ioctl');
    final close = libc.lookupFunction<_Close, _CloseD>('close');
    final calloc = libc.lookupFunction<_Calloc, _CallocD>('calloc');
    final free = libc.lookupFunction<_Free, _FreeD>('free');

    final bytes = [...path.codeUnits, 0];
    final p = calloc(bytes.length, 1);
    final info = calloc(_absInfoSize, 1);
    try {
      p.asTypedList(bytes.length).setAll(0, bytes);
      final fd = open(p, _oRdonly | _oNonblock | _oCloexec);
      if (fd < 0) return null;
      try {
        if (ioctl(fd, eviocgabs(abs), info) < 0) return null;
        final v = info.cast<Int32>().asTypedList(6);
        if (v[2] <= v[1]) return null;
        return (v[1], v[2]);
      } finally {
        close(fd);
      }
    } finally {
      free(p);
      free(info);
    }
  } on Object {
    return null;
  }
}
