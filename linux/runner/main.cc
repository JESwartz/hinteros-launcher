#include "my_application.h"

#include <string.h>

// One binary, two apps: `--osk` (what the hinteros-osk wrapper passes) or
// HINTEROS_OSK=1 makes this the on-screen keyboard.
static gboolean is_osk(int argc, char** argv) {
  if (g_strcmp0(g_getenv("HINTEROS_OSK"), "1") == 0) return TRUE;
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--osk") == 0) return TRUE;
  }
  return FALSE;
}

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new(is_osk(argc, argv));
  return g_application_run(G_APPLICATION(app), argc, argv);
}
