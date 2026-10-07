// Unit test for is_gdk_gl_dummy (built and run by the gl-dummy-logic check).
#include <cstdio>
#include <cstdlib>

#include "gl_dummy.h"

static int failures = 0;
#define EXPECT(cond)                                         \
  do {                                                       \
    if (!(cond)) {                                           \
      std::fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #cond); \
      failures++;                                            \
    }                                                        \
  } while (0)

int main() {
  const uint32_t top = 0x04200010, leader = 0x04200002;
  const uint32_t mine = 0x04200123, other = 0x03a00123;
  EXPECT(is_gdk_gl_dummy({mine, true, true, false}, top, leader));
  EXPECT(!is_gdk_gl_dummy({other, true, true, false}, top, leader));  // foreign
  EXPECT(!is_gdk_gl_dummy({top, true, true, false}, top, leader));
  EXPECT(!is_gdk_gl_dummy({leader, true, true, false}, top, leader));
  EXPECT(!is_gdk_gl_dummy({mine, false, true, false}, top, leader));  // managed
  EXPECT(!is_gdk_gl_dummy({mine, true, false, false}, top, leader));  // unmapped
  EXPECT(!is_gdk_gl_dummy({mine, true, true, true}, top, leader));    // GDK's
  EXPECT(is_gdk_gl_dummy({mine, true, true, false}, top, 0));
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
