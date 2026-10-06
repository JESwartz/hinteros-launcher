#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  gboolean osk;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
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
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, self->osk ? "#00000000" : "#000000");
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

  // Hide the mouse cursor in console mode (best effort).
  if (!windowed) {
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(view));
    if (gdk_window != nullptr) {
      g_autoptr(GdkCursor) blank = gdk_cursor_new_for_display(
          gdk_window_get_display(gdk_window), GDK_BLANK_CURSOR);
      gdk_window_set_cursor(gdk_window, blank);
    }
  }

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

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
