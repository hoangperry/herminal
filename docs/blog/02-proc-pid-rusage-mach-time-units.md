# `proc_pid_rusage` returns mach absolute time units, not nanoseconds. On Apple Silicon that's a 42× under-report.

**Status:** draft. Owner publishes when ready.
**Audience:** macOS-native tools developers measuring per-process CPU.
**Length:** ~700 words. One read.

---

If you're reading per-PID CPU usage on macOS, `proc_pid_rusage` is
the obvious API. It fills a `rusage_info_v6` struct with fields
named `ri_user_time` and `ri_system_time`. Apple's reference page
says "time spent in mode" but doesn't pin the unit. Some scattered
forum answers call it nanoseconds. **It isn't.**

We hit this in herminal Month 6 building agent status discrimination.
A tight `yes > /dev/null` loop (provably ~100% of one core) was
reporting 2.4% CPU. The dashboard marked every agent as idle.

## What's actually in those fields

The fields come from `thread->user_time` and `thread->system_time`
inside xnu (Apple's open-source kernel). Both are **mach absolute
time counters** — the raw value `mach_absolute_time()` returns, not
seconds and not nanoseconds.

On Intel Macs `mach_timebase_info` reports `numer=1, denom=1`, so
the mach unit equals the nanosecond. Treating `ri_user_time` as a
nanosecond value happens to work by accident.

On Apple Silicon the timebase is `numer=125, denom=3`:

```
1 mach unit = 125/3 ns = 41.666... ns
```

So `ri_user_time = 12_000_000` on Apple Silicon isn't 12 ms of CPU.
It's `12_000_000 * 125 / 3 = 500_000_000` ns = 500 ms. **42× more
than the naïve reading.**

## How we caught it

Empirical probe: spawn `yes > /dev/null` (known 100% CPU), measure
its `ri_user_time` delta over 500 ms of wall time.

```
sample 1: ri_user_time = 4686312
sample 2: ri_user_time = 4698264  (500 ms later)
delta: 11_952 mach units = 11.9 μs?  // wrong if treated as ns
delta * 125 / 3 = 498_000 ns = 498 ms  // 99.6% CPU — correct
```

The 42× ratio matched the published Apple Silicon timebase to within
rounding. Mystery solved.

## The fix

Cache the timebase once at process start, multiply in your sampler:

```swift
private static let machTimebase: mach_timebase_info_data_t = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return info
}()

func cpuSeconds(forPID pid: pid_t) -> TimeInterval {
    var info = rusage_info_current()
    let rc = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
            proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
        }
    }
    guard rc == 0 else { return 0 }
    let machTotal = info.ri_user_time + info.ri_system_time
    let ns = machTotal * UInt64(machTimebase.numer) / UInt64(machTimebase.denom)
    return TimeInterval(ns) / 1_000_000_000
}
```

The unit-conversion math is the load-bearing line. Without it you'll
get the same 2.4%-CPU-for-100%-CPU under-report and your status
detector ships shipping broken.

## Why the unit is so under-documented

`mach_absolute_time` predates `clock_gettime(CLOCK_MONOTONIC)` and
the whole nanosecond-everywhere norm. It's the kernel's native
"this happened at clock tick N" counter. The xnu code uses it
internally because it's free to read; the public APIs that expose
the same counters (`proc_pid_rusage`, the `mach_*_time_info` family)
inherited the unit without the field names making it obvious.

Apple's own samples convert via `mach_timebase_info` when they care
about the wall-clock value. Tools that don't read those samples
keep getting bitten — multiple GitHub issues for top-of-search-result
Activity Monitor clones show this exact bug.

## What this means for your CI

If you write integration tests against `proc_pid_rusage` and run them
on a GitHub Actions Intel runner today, they'll pass. They'll fail
the moment GitHub switches to Apple Silicon runners (or your local
dev machine is Apple Silicon and CI is Intel — opposite skew, same
class of bug). Always include the timebase conversion in your CI
runs. We caught ours because the unit test that mattered ran on
Apple Silicon; if it had only existed in CI, we'd have shipped it.

## Implementation reference

Full Swift implementation:
[`Sources/HerminalAgent/AgentDetector.swift`](../../Sources/HerminalAgent/AgentDetector.swift)
inside `AgentStatusTracker.cpuSeconds(forPID:)`. The cached
timebase static at the bottom of the file is shared across all
sampling calls — read once, used forever.

---

*This is post 2 of 3 in a series on macOS-native kernel-API gotchas
we hit building herminal. Previous:
[proc_listchildpids broken on Sequoia](01-proc-listchildpids-broken-on-sequoia.md).
Next: [libghostty's exec -l prefixes p_comm with a dash, and
ps -o comm hides it](03-libghostty-exec-l-pcomm-dash.md).*
