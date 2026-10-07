// Recognising GTK's GLX "dummy" window. Pure logic, no X11 headers, so
// linux/runner/gl_dummy_test.cc can unit-test it.
//
// GTK 3.24 creates a 1x1 override-redirect window at -100,-100 (own
// colormap, mapped at once, never drawn) when a widget gets a GL context.
// Under gamescope that window can become the focus window and be resized to
// the whole output, painting black over the real toplevel. We unmap it.
#ifndef RUNNER_GL_DUMMY_H_
#define RUNNER_GL_DUMMY_H_

#include <cstdint>

struct X11WindowInfo {
  uint32_t xid;
  bool override_redirect;
  bool viewable;        // map_state == IsViewable
  bool known_to_gdk;    // gdk_x11_window_lookup_for_display() != NULL
};

// X resource ids carry the client's base in the high bits; the low 21 bits
// are the client's own counter (the default resource-id-mask).
static const uint32_t kX11ResourceMask = 0x1fffff;

// True when [w], a child of the root, is a GDK GL dummy of *our* client
// (whose toplevel is [toplevel] and WM client leader [leader], or 0).
static inline bool is_gdk_gl_dummy(const X11WindowInfo& w, uint32_t toplevel,
                                   uint32_t leader) {
  if ((w.xid & ~kX11ResourceMask) != (toplevel & ~kX11ResourceMask))
    return false;  // another client's window: never touch
  if (w.xid == toplevel || (leader != 0 && w.xid == leader)) return false;
  return w.override_redirect && w.viewable && !w.known_to_gdk;
}

#endif  // RUNNER_GL_DUMMY_H_
