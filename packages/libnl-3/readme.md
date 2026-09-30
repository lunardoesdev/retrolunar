# libnl-3 on Android: `--disable-pthreads` and the caches it stops guarding

`packages/libnl-3/android.lua` passes `--disable-pthreads`. That flag is not
a build workaround with no consequences — it changes the locking inside the
library, and this note records exactly what is lost so the next person who
sees a bug does not go looking in the wrong place.

**This package has never been built.** Its `stage3.md` records a blocked
build: `flex@clang-native` will not build (see that file), so nothing here
is a report of observed runtime behaviour. Everything below was read out of
the upstream 3.12.0 tree and is cited to a file and line.

## Why the flag exists

`configure.ac:112-119`:

```m4
AC_ARG_ENABLE([pthreads],
	AS_HELP_STRING([--disable-pthreads], [Disable pthreads support]),
	[enable_pthreads="$enableval"], [enable_pthreads="yes"])
AM_CONDITIONAL([DISABLE_PTHREADS], [test "$enable_pthreads" = "no"])
if test "x$enable_pthreads" = "xno"; then
    AC_DEFINE([DISABLE_PTHREADS], [1], [Define to 1 to disable pthreads])
else
    AC_CHECK_LIB([pthread], [pthread_mutex_lock], [], AC_MSG_ERROR([libpthread is required]))
fi
```

Bionic has no `libpthread` at any API level — the NDK sysroot ships no
`libpthread.a` and no `libpthread.so`, and linking `-lpthread` fails with
`ld.lld: error: unable to find library -lpthread`. That is not a gap to be
filled: pthreads are in libc on Bionic, there is no separate library to
find. But `AC_CHECK_LIB` looks for a *library*, finds none, and the
`else` arm turns that into `AC_MSG_ERROR([libpthread is required])`, which
aborts configure. It is a hard error, not a warning.

The `else` arm is the whole problem: pthreads genuinely exist and work on
Android, so the check is asking the wrong question. `--disable-pthreads` is
upstream's own switch for "do not ask", and it is the correct choice here
because the alternative is not building the package at all.

## What the flag actually does

`--disable-pthreads` defines `DISABLE_PTHREADS`, which selects a completely
different set of lock macros in `include/base/nl-base-utils.h`.

**With pthreads** (`:829-831` and following):

```c
#define NL_LOCK(NAME) pthread_mutex_t(NAME) = PTHREAD_MUTEX_INITIALIZER
#define NL_RW_LOCK(NAME) pthread_rwlock_t(NAME) = PTHREAD_RWLOCK_INITIALIZER

static inline void nl_lock(pthread_mutex_t *lock)
{
	pthread_mutex_lock(lock);
}
```

**Without pthreads** (`:864-880`):

```c
#define NL_LOCK(NAME) int __unused_lock_##NAME _nl_unused
#define NL_RW_LOCK(NAME) int __unused_lock_##NAME _nl_unused

#define nl_lock(LOCK) \
	do {          \
	} while (0)
#define nl_unlock(LOCK) \
	do {            \
	} while (0)
```

`nl_lock`, `nl_unlock`, `nl_read_lock`, `nl_read_unlock` and
`nl_write_lock` all become **empty statements**. The lock variables are not
even declared as locks any more — `NL_LOCK(NAME)` expands to an unused
`int`. And `<pthread.h>` is not included at all (`:23-25`).

So `--disable-pthreads` does not substitute a cheaper lock or a no-op stub
that still costs something. It removes the synchronisation completely.

## What is consequently unguarded

Three internal caches in libnl. This is the complete list, from
`grep -rn 'NL_LOCK(\|NL_RW_LOCK(' lib/*.c`:

| cache | declaration | what it protects |
| --- | --- | --- |
| `cache_ops` | `lib/cache_mngt.c:34` — `static NL_RW_LOCK(cache_ops_lock)` | the cache-operations dispatch table, looked up on **every** `nl_cache_*` call |
| `port_map` | `lib/socket.c:84` — `static NL_RW_LOCK(port_map_lock)` | the socket-local ↔ netlink socket map |
| `mutex` | `lib/utils.c:497` — `NL_LOCK(mutex)` | the libnl internal allocator |

The first is the one that matters. `cache_ops` is consulted on every single
cache lookup, and libnl caches are documented as *not* thread-safe per
handle — a single `struct nl_cache` must not be shared between threads
regardless of this flag. What `cache_ops_lock` guards is the shared,
process-wide dispatch table behind those per-handle caches. With the lock
compiled out, two threads reaching the table at once can observe it
mid-initialisation.

`port_map` is a small lookup that maps a local socket fd to its netlink
socket. Two threads creating sockets concurrently can race on it. In
practice this needs threads that are already touching libnl at the same
instant.

## The honest risk statement

**This is a data race that exists but is very unlikely to fire in the way
this prefix uses libnl.**

- It cannot fire for a single-threaded caller, which is most embedded
  netlink use — one netlink socket, one event loop, done.
- It cannot fire across *processes*. The caches in question are
  process-local static variables; separate processes get separate copies.
- It can fire when **multiple threads in one process** use libnl
  concurrently, which is the case a netlink socket pool or any threaded
  daemon hits.

So the failure mode is: a threaded consumer on Android sees, very rarely, a
stale or half-initialised cache-ops pointer. It would present as a crash or
a null dereference inside an `nl_cache_*` call, in a program that was
written and tested as if libnl were internally synchronised.

**This is not a reason to drop the flag.** The alternative is not "keep the
locks" but "do not build libnl-3 on Android at all", and a working library
with a narrow, documented race is worth more than none. But it is a reason
to document it, which is what this file is for.

## If a threaded consumer ever shows up

The fix is upstream's, not this repo's, because no recipe change can
restore a lock libnl has been told not to compile:

1. **Best: an upstream configure change.** Make the `AC_CHECK_LIB` probe
   look for the *symbol* rather than a library —
   `AC_SEARCH_LIBS([pthread_mutex_lock], [pthread])` already degrades to
   "found it in libc" when no `-lpthread` is needed, which is exactly the
   Android case. That is a one-line change in `configure.ac:118`, and it
   would let `--enable-pthreads` work everywhere.
2. **Workaround if that is not accepted:** keep the library as it is and
   serialise libnl access in the consumer with an application-level lock
   around the `nl_cache_*` and socket-creation paths. That is correct, just
   coarser than the library's own internal locking.

Neither is something `packages/libnl-3/android.lua` should do. A recipe that
defined `HAVE_C_BOOL`-style macros by hand, or pre-set
`ac_cv_lib_pthread_pthread_mutex_lock=yes`, would be working around an
upstream defect in a recipe, which AGENTS.md forbids.

## Verification notes

- The `libpthread` absence claim was checked by the reviewer against the NDK
  r28b sysroot and by a link attempt, not inferred.
- Every line number above is from the unpacked `libnl-3.12.0` tree, read
  during this review of the recipe. They are cited rather than paraphrased
  because this note is the only durable record of the regression — the
  recipe's own comment is four lines and cannot hold it.
- **Nothing in this note has been confirmed by a running library.** The
  package has not built on any Android system. The next person who gets it
  built should confirm the artifacts (`ls $PREFIX/lib/libnl-*-3.a | wc -l`
  → 6, `pkg-config --modversion libnl-3.0` → 3.12.0) and can confirm the
  race is latent rather than absent only by reasoning, which is all that is
  available here.
