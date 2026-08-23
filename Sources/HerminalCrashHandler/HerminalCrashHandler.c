#include "HerminalCrashHandler.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t crash_descriptor = -1;

static const char sigsegv_message[] = "\n=== CRASHED signal=11 ===\n";
static const char sigbus_message[] = "\n=== CRASHED signal=10 ===\n";
static const char sigabrt_message[] = "\n=== CRASHED signal=6 ===\n";
static const char sigill_message[] = "\n=== CRASHED signal=4 ===\n";
static const char sigfpe_message[] = "\n=== CRASHED signal=8 ===\n";

static const char *crash_message_for_signal(int32_t signal_number, size_t *length) {
    if (length == NULL) {
        return NULL;
    }
    switch (signal_number) {
    case SIGSEGV:
        *length = sizeof(sigsegv_message) - 1;
        return sigsegv_message;
    case SIGBUS:
        *length = sizeof(sigbus_message) - 1;
        return sigbus_message;
    case SIGABRT:
        *length = sizeof(sigabrt_message) - 1;
        return sigabrt_message;
    case SIGILL:
        *length = sizeof(sigill_message) - 1;
        return sigill_message;
    case SIGFPE:
        *length = sizeof(sigfpe_message) - 1;
        return sigfpe_message;
    default:
        *length = 0;
        return NULL;
    }
}

const char *herminal_crash_message_for_signal(int32_t signal_number, size_t *length) {
    return crash_message_for_signal(signal_number, length);
}

int32_t herminal_duplicate_crash_descriptor(int32_t descriptor) {
    return fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
}

static void write_all(int32_t descriptor, const char *bytes, size_t byte_count) {
    size_t total_written = 0;
    while (total_written < byte_count) {
        const ssize_t result = write(
            descriptor,
            bytes + total_written,
            byte_count - total_written
        );
        if (result > 0) {
            total_written += (size_t)result;
        } else if (result < 0 && errno == EINTR) {
            continue;
        } else {
            return;
        }
    }
}

static void crash_signal_handler(int signal_number) {
    const int saved_errno = errno;
    size_t length = 0;
    const char *message = crash_message_for_signal(signal_number, &length);
    const int32_t descriptor = (int32_t)crash_descriptor;
    if (descriptor >= 0 && message != NULL) {
        write_all(descriptor, message, length);
    }

    struct sigaction default_action;
    default_action.sa_handler = SIG_DFL;
    default_action.sa_flags = 0;
    sigemptyset(&default_action.sa_mask);
    sigaction(signal_number, &default_action, NULL);
    raise(signal_number);
    errno = saved_errno;
}

int32_t herminal_install_crash_handlers(int32_t descriptor) {
    const int32_t duplicate = herminal_duplicate_crash_descriptor(descriptor);
    if (duplicate < 0) {
        return -1;
    }

    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = crash_signal_handler;
    sigemptyset(&action.sa_mask);

    crash_descriptor = (sig_atomic_t)duplicate;
    const int signals[] = {SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE};
    const size_t signal_count = sizeof(signals) / sizeof(signals[0]);
    for (size_t index = 0; index < signal_count; ++index) {
        if (sigaction(signals[index], &action, NULL) != 0) {
            crash_descriptor = -1;
            close(duplicate);
            return -1;
        }
    }
    return 0;
}
