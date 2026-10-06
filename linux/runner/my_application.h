#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication,
                     my_application,
                     MY,
                     APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 *
 * @osk: TRUE for the on-screen keyboard (hinteros-osk): a transparent,
 *   undecorated ARGB overlay window with WM_CLASS "hinteros-osk".
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new(gboolean osk);

#endif  // FLUTTER_MY_APPLICATION_H_
