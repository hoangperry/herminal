#ifndef HERMINAL_CRASH_HANDLER_H
#define HERMINAL_CRASH_HANDLER_H

#include <stddef.h>
#include <stdint.h>

const char *herminal_crash_message_for_signal(int32_t signal_number, size_t *length);
int32_t herminal_duplicate_crash_descriptor(int32_t descriptor);
int32_t herminal_install_crash_handlers(int32_t descriptor);

#endif
