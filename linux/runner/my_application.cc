#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "gl_dummy.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  gboolean osk;
  gboolean hide_pointer;
  // Tells the Dart side whether the window has keyboard focus (channel
  // "hinteros/window"), see lib/src/installer/keyboard_fallback.dart.
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Blanks the pointer on [widget]'s GdkWindow. Works on X11 and on Wayland
// (the compositor shows no pointer image for a blank cursor). Safe to call
// repeatedly; does nothing before the widget is realized.
static void hide_cursor(GtkWidget* widget) {
  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  if (gdk_window == nullptr) return;
  g_autoptr(GdkCursor) blank = gdk_cursor_new_for_display(
      gdk_window_get_display(gdk_window), GDK_BLANK_CURSOR);
  gdk_window_set_cursor(gdk_window, blank);
}

// Console mode: hide the pointer on the Flutter view and its window. Done at
// realize, map and first frame because GTK and Wayland compositors reset the
// cursor on enter events; the Dart side also sets Flutter's own cursor to
// none.
static void hide_cursors(MyApplication* self, GtkWidget* view) {
  if (!self->hide_pointer) return;
  hide_cursor(view);
  hide_cursor(gtk_widget_get_toplevel(view));
}

// Diagnostics for the keyboard-focus problem seen on real hardware under
// cage: everything goes to stderr, prefixed so it can be grepped.
static void focus_log(const char* format, ...) G_GNUC_PRINTF(1, 2);
static void focus_log(const char* format, ...) {
  va_list args;
  va_start(args, format);
  g_autofree gchar* message = g_strdup_vprintf(format, args);
  va_end(args);
  g_printerr("hinteros-focus: %s\n", message);
}

// Lists every toplevel GTK knows: an extra (hidden or helper) window that the
// compositor could give the focus to instead of ours would show up here.
static void log_toplevels(const char* when) {
  GList* all = gtk_window_list_toplevels();
  focus_log("%s: %u GTK toplevel(s)", when, g_list_length(all));
  for (GList* l = all; l != nullptr; l = l->next) {
    GtkWindow* w = GTK_WINDOW(l->data);
    focus_log("  toplevel %p \"%s\" visible=%d active=%d mapped=%d", (void*)w,
              gtk_window_get_title(w) ? gtk_window_get_title(w) : "",
              gtk_widget_get_visible(GTK_WIDGET(w)), gtk_window_is_active(w),
              gtk_widget_get_mapped(GTK_WIDGET(w)));
  }
  g_list_free(all);
}

// Sends the window's keyboard focus state to Dart.
static void send_focus(MyApplication* self, GtkWindow* window,
                       const char* why) {
  gboolean active = gtk_window_is_active(window);
  focus_log("%s: is-active=%d has-toplevel-focus=%d", why, active,
            gtk_window_has_toplevel_focus(window));
  if (self->window_channel == nullptr) return;
  g_autoptr(FlValue) value = fl_value_new_bool(active);
  fl_method_channel_invoke_method(self->window_channel, "focus", value, nullptr,
                                  nullptr, nullptr);
}

static void active_cb(GObject* window, GParamSpec*, gpointer user_data) {
  send_focus(MY_APPLICATION(user_data), GTK_WINDOW(window), "notify::is-active");
}

static void toplevel_focus_cb(GObject* window, GParamSpec*,
                              gpointer user_data) {
  send_focus(MY_APPLICATION(user_data), GTK_WINDOW(window),
             "notify::has-toplevel-focus");
}

static gboolean focus_event_cb(GtkWidget* window, GdkEventFocus* event,
                               gpointer user_data) {
  focus_log("focus-%s-event", event->in ? "in" : "out");
  send_focus(MY_APPLICATION(user_data), GTK_WINDOW(window),
             event->in ? "focus-in-event" : "focus-out-event");
  return FALSE;
}

// The channel Dart asks "isActive" on at startup (messages sent before its
// handler exists are lost).
static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(call), "isActive") == 0) {
    GtkWindow* window = GTK_WINDOW(
        gtk_widget_get_toplevel(GTK_WIDGET(g_object_get_data(
            G_OBJECT(self), "hinteros-view"))));
    g_autoptr(FlValue) result =
        fl_value_new_bool(window != nullptr && gtk_window_is_active(window));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

static guint32 present_time() {
  guint32 t = gtk_get_current_event_time();
  // No event yet (before the first input): the monotonic clock in ms, which
  // is what the compositor's own timestamps count.
  return t != GDK_CURRENT_TIME ? t : (guint32)(g_get_monotonic_time() / 1000);
}

static void present_window(GtkWindow* window, const char* why) {
  guint32 t = present_time();
  focus_log("present (%s) at time %u, active=%d", why, t,
            gtk_window_is_active(window));
  gtk_window_present_with_time(window, t);
  GdkWindow* gdk = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk != nullptr) gdk_window_focus(gdk, t);
}

// Asks again while the window still has no keyboard focus (the compositor
// may only hand it out once the keyboard device exists), a few times.
static gboolean refocus_cb(gpointer data) {
  GtkWindow* window = GTK_WINDOW(data);
  guint tries = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(window), "hinteros-tries"));
  if (gtk_window_is_active(window) || tries >= 20) {
    focus_log("refocus: stop after %u tries, active=%d", tries,
              gtk_window_is_active(window));
    g_object_unref(window);
    return G_SOURCE_REMOVE;
  }
  g_object_set_data(G_OBJECT(window), "hinteros-tries",
                    GUINT_TO_POINTER(tries + 1));
  present_window(window, "retry");
  GtkWidget* view = GTK_WIDGET(g_object_get_data(G_OBJECT(window), "hinteros-view"));
  if (view != nullptr) gtk_widget_grab_focus(view);
  return G_SOURCE_CONTINUE;
}

// Takes keyboard focus (the compositor gives it to the toplevel that asks,
// and without a pointer click nothing else would), and gives it to the
// Flutter view so key events reach Flutter before any other input.
static void focus_view(MyApplication* self, FlView* view) {
  if (self->osk) return;  // the keyboard never takes focus
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (GTK_IS_WINDOW(toplevel)) {
    GtkWindow* window = GTK_WINDOW(toplevel);
    gtk_window_set_accept_focus(window, TRUE);
    gtk_window_set_focus_on_map(window, TRUE);
    present_window(window, "map/first frame");
    if (g_object_get_data(G_OBJECT(window), "hinteros-refocus") == nullptr) {
      g_object_set_data(G_OBJECT(window), "hinteros-refocus", GINT_TO_POINTER(1));
      g_timeout_add(500, refocus_cb, g_object_ref(window));
    }
    log_toplevels("after present");
    send_focus(self, window, "after present");
  }
  gtk_widget_set_can_focus(GTK_WIDGET(view), TRUE);
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Unmaps GTK's GLX "dummy" window (see gl_dummy.h): under gamescope it
// becomes the focus window, is resized to the output and ends up painted
// above the real toplevel (black screen). Only windows of our own X client
// that GDK does not know are touched. Safe to call repeatedly.
static void unmap_gl_dummies(GtkWidget* widget) {
#ifdef GDK_WINDOWING_X11
  GtkWidget* top = gtk_widget_get_toplevel(widget);
  GdkWindow* gdk_top = top != nullptr ? gtk_widget_get_window(top) : nullptr;
  if (gdk_top == nullptr || !GDK_IS_X11_WINDOW(gdk_top)) return;
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_top);
  Display* xdisplay = GDK_DISPLAY_XDISPLAY(gdk_display);
  Window toplevel = GDK_WINDOW_XID(gdk_top);

  // The WM client leader (GTK's hidden group window), if set.
  Window leader = 0;
  {
    Atom type;
    int format;
    unsigned long n, after;
    unsigned char* data = nullptr;
    if (XGetWindowProperty(xdisplay, toplevel,
                           gdk_x11_get_xatom_by_name_for_display(
                               gdk_display, "WM_CLIENT_LEADER"),
                           0, 1, False, XA_WINDOW, &type, &format, &n, &after,
                           &data) == Success &&
        data != nullptr) {
      if (type == XA_WINDOW && format == 32 && n == 1)
        leader = *reinterpret_cast<Window*>(data);
      XFree(data);
    }
  }

  Window root, parent, *children = nullptr;
  unsigned int count = 0;
  Window xroot = GDK_WINDOW_XID(
      gdk_screen_get_root_window(gdk_window_get_screen(gdk_top)));
  if (!XQueryTree(xdisplay, xroot, &root, &parent, &children, &count)) return;
  for (unsigned int i = 0; i < count; i++) {
    XWindowAttributes attrs;
    gdk_x11_display_error_trap_push(gdk_display);
    Status ok = XGetWindowAttributes(xdisplay, children[i], &attrs);
    if (gdk_x11_display_error_trap_pop(gdk_display) != 0 || !ok) continue;
    X11WindowInfo info = {
        static_cast<uint32_t>(children[i]), attrs.override_redirect != False,
        attrs.map_state == IsViewable,
        gdk_x11_window_lookup_for_display(gdk_display, children[i]) !=
            nullptr};
    if (!is_gdk_gl_dummy(info, static_cast<uint32_t>(toplevel),
                         static_cast<uint32_t>(leader)))
      continue;
    gdk_x11_display_error_trap_push(gdk_display);
    XUnmapWindow(xdisplay, children[i]);
    XFlush(xdisplay);
    gdk_x11_display_error_trap_pop_ignored(gdk_display);
    g_printerr("hinteros-x11: unmapped GDK GL dummy window 0x%lx\n",
               static_cast<unsigned long>(children[i]));
  }
  if (children != nullptr) XFree(children);
#else
  (void)widget;
#endif
}

static gboolean unmap_gl_dummies_timeout_cb(gpointer data) {
  unmap_gl_dummies(GTK_WIDGET(data));
  return G_SOURCE_REMOVE;
}

// Now, and again shortly after (the dummy may appear late).
static void unmap_gl_dummies_now_and_later(GtkWidget* view) {
  unmap_gl_dummies(view);
  static const guint delays[] = {100, 500, 1500};
  for (guint delay : delays)
    g_timeout_add_full(G_PRIORITY_DEFAULT, delay, unmap_gl_dummies_timeout_cb,
                       g_object_ref(view), g_object_unref);
}

static void window_map_cb(GtkWidget* window, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  focus_log("window mapped (display %s)",
            G_OBJECT_TYPE_NAME(gtk_widget_get_display(window)));
  gpointer view = g_object_get_data(G_OBJECT(window), "hinteros-view");
  if (view == nullptr) return;
  hide_cursors(self, GTK_WIDGET(view));
  unmap_gl_dummies(GTK_WIDGET(view));
  focus_view(self, FL_VIEW(view));
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  focus_log("first Flutter frame");
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  hide_cursors(self, GTK_WIDGET(view));
  unmap_gl_dummies(GTK_WIDGET(view));
  focus_view(self, view);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Console mode (default): fullscreen and undecorated, as the only app under
  // gamescope/cage. --windowed or HINTEROS_WINDOWED=1 gives a normal
  // decorated 1280x720 window for desktop development.
  gboolean windowed = g_strcmp0(g_getenv("HINTEROS_WINDOWED"), "1") == 0;
  if (self->dart_entrypoint_arguments != nullptr) {
    for (char** arg = self->dart_entrypoint_arguments; *arg != nullptr; arg++) {
      if (g_strcmp0(*arg, "--windowed") == 0) {
        windowed = TRUE;
      }
    }
  }

  self->hide_pointer = !windowed;

  if (self->osk) {
    // GTK capitalises the program class ("Hinteros-osk"); set WM_CLASS
    // explicitly (deprecated, but the only way that sticks) so both name and
    // class are "hinteros-osk".
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    gtk_window_set_wmclass(window, "hinteros-osk", "hinteros-osk");
    G_GNUC_END_IGNORE_DEPRECATIONS
    // On-screen keyboard: an ARGB (32-bit visual) window with a transparent
    // Flutter background; gamescope composites it as an external overlay
    // (see below). The daemon finds it by WM_CLASS "hinteros-osk".
    GdkScreen* screen = gtk_widget_get_screen(GTK_WIDGET(window));
    GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
    if (visual != nullptr) {
      gtk_widget_set_visual(GTK_WIDGET(window), visual);
    } else {
      g_warning("No RGBA visual: the keyboard window cannot be transparent");
    }
    gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  }

  if (windowed) {
    gtk_window_set_title(window, self->osk ? "HinterOS keyboard" : "HinterOS");
    gtk_window_set_default_size(window, 1280, 720);
  } else if (self->osk) {
    // Covers the whole output, undecorated, never takes keyboard focus (the
    // daemon routes the pad to us and types through uinput).
    gtk_window_set_title(window, "HinterOS keyboard");
    gtk_window_set_decorated(window, FALSE);
    gtk_window_set_accept_focus(window, FALSE);
    gtk_window_set_focus_on_map(window, FALSE);
    gtk_window_set_skip_taskbar_hint(window, TRUE);
    gtk_window_set_keep_above(window, TRUE);
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
    if (monitor == nullptr) monitor = gdk_display_get_monitor(display, 0);
    GdkRectangle area = {0, 0, 1920, 1080};
    if (monitor != nullptr) gdk_monitor_get_geometry(monitor, &area);
    gtk_window_set_default_size(window, area.width, area.height);
    gtk_window_move(window, area.x, area.y);
  } else {
    gtk_window_set_decorated(window, FALSE);
    gtk_window_fullscreen(window);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // The theme background (HinterTokens.background), so the window matches the
  // loading screens before the first frame; the keyboard is transparent.
  gdk_rgba_parse(&background_color, self->osk ? "#00000000" : "#0E1118");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

#ifdef GDK_WINDOWING_X11
  if (self->osk) {
    // GAMESCOPE_EXTERNAL_OVERLAY=1: gamescope paints the window above the
    // running app without ever giving it focus (spike 5). Visible while
    // _NET_WM_WINDOW_OPACITY is non-zero; the daemon toggles that.
    gtk_widget_realize(GTK_WIDGET(window));
    GdkWindow* toplevel = gtk_widget_get_window(GTK_WIDGET(window));
    if (toplevel != nullptr && GDK_IS_X11_WINDOW(toplevel)) {
      gulong one = 1;
      gdk_property_change(toplevel,
                          gdk_atom_intern("GAMESCOPE_EXTERNAL_OVERLAY", FALSE),
                          gdk_atom_intern("CARDINAL", FALSE), 32,
                          GDK_PROP_MODE_REPLACE,
                          reinterpret_cast<const guchar*>(&one), 1);
    }
  }
#endif

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));
  unmap_gl_dummies_now_and_later(GTK_WIDGET(view));

  // Hide the mouse cursor in console mode, installer included (best effort;
  // repeated on map and first frame).
  hide_cursors(self, GTK_WIDGET(view));
  g_object_set_data(G_OBJECT(window), "hinteros-view", view);
  g_signal_connect(window, "map", G_CALLBACK(window_map_cb), self);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  if (!self->osk) {
    // Keyboard focus tracking: log it, and tell Dart (the installer falls
    // back to reading the keyboard itself while the window has no focus).
    g_object_set_data(G_OBJECT(self), "hinteros-view", view);
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    self->window_channel = fl_method_channel_new(
        fl_engine_get_binary_messenger(fl_view_get_engine(view)),
        "hinteros/window", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(self->window_channel,
                                             window_method_cb, self, nullptr);
    g_signal_connect(window, "notify::is-active", G_CALLBACK(active_cb), self);
    g_signal_connect(window, "notify::has-toplevel-focus",
                     G_CALLBACK(toplevel_focus_cb), self);
    g_signal_connect(window, "focus-in-event", G_CALLBACK(focus_event_cb),
                     self);
    g_signal_connect(window, "focus-out-event", G_CALLBACK(focus_event_cb),
                     self);
    log_toplevels("startup");
  }

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new(gboolean osk) {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  //
  // The keyboard is told apart by its X11 window class, which GTK derives
  // from the program name and class: both "hinteros-osk" (the daemon finds
  // the window by it). Must happen before GTK opens the display.
  if (osk) {
    g_set_prgname("hinteros-osk");
    gdk_set_program_class("hinteros-osk");
  } else {
    g_set_prgname(APPLICATION_ID);
  }

  MyApplication* self = MY_APPLICATION(g_object_new(
      my_application_get_type(), "application-id",
      osk ? OSK_APPLICATION_ID : APPLICATION_ID, "flags",
      G_APPLICATION_NON_UNIQUE, nullptr));
  self->osk = osk;
  return self;
}
