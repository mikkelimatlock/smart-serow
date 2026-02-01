#ifndef RPM_H
#define RPM_H

void rpm_init();
void rpm_update();      // Call in loop
int rpm_get();          // Returns current RPM (0 if invalid)

#endif
