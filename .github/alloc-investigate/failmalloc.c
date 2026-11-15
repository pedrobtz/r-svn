#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *(*real_malloc)(size_t);
static void *(*real_calloc)(size_t, size_t);
static void *(*real_realloc)(void *, size_t);
static void  (*real_free)(void *);

static long fail_at = 0;   /* 0 disables injection */
static long counter = 0;
static int  ready = 0;
static int  resolving = 0;

static char   arena[1 << 16];
static size_t arena_used = 0;

/* Each block carries its size in a 16-byte header, so a realloc
   out of the arena copies what the block held -- not the new
   size, which read past it, and past the arena at its end. */
static void *arena_alloc(size_t n) {
  if (n > sizeof arena) return NULL;
  size_t a = 16u + ((n + 15u) & ~(size_t)15u);
  if (arena_used + a > sizeof arena) return NULL;
  char *p = arena + arena_used;
  arena_used += a;
  *(size_t *)p = n;
  return p + 16;
}

static size_t arena_size(void *p) {
  return *(size_t *)((char *)p - 16);
}

static int from_arena(void *p) {
  return (char *)p >= arena && (char *)p < arena + sizeof arena;
}

static void init(void) {
  if (ready || resolving) return;
  resolving = 1;
  real_malloc  = (void *(*)(size_t))         dlsym(RTLD_NEXT, "malloc");
  real_calloc  = (void *(*)(size_t, size_t)) dlsym(RTLD_NEXT, "calloc");
  real_realloc = (void *(*)(void *, size_t)) dlsym(RTLD_NEXT, "realloc");
  real_free    = (void (*)(void *))           dlsym(RTLD_NEXT, "free");
  const char *e = getenv("ALLOC_FAIL_AT");
  fail_at = e ? atol(e) : 0;
  resolving = 0;
  ready = 1;
}

/* Counts every allocation whether or not one is being failed, so a
   pass with injection off reports how many there are to sweep. */
static int should_fail(void) {
  long n = ++counter;
  return fail_at > 0 && n == fail_at;
}

void *malloc(size_t size) {
  if (resolving) return arena_alloc(size);
  init();
  if (!real_malloc) return arena_alloc(size);
  if (should_fail()) { errno = ENOMEM; return NULL; }
  return real_malloc(size);
}

void *calloc(size_t nmemb, size_t size) {
  if (resolving || !real_calloc) {
    if (size && nmemb > (size_t)-1 / size) return NULL;
    void *p = arena_alloc(nmemb * size);
    if (!resolving) init();
    if (p) memset(p, 0, nmemb * size);
    return p;
  }
  init();
  if (should_fail()) { errno = ENOMEM; return NULL; }
  return real_calloc(nmemb, size);
}

void *realloc(void *ptr, size_t size) {
  init();
  if (from_arena(ptr)) {
    void *p = malloc(size);
    if (p) {
      size_t old = arena_size(ptr);
      memcpy(p, ptr, old < size ? old : size);
    }
    return p;
  }
  if (!real_realloc) return arena_alloc(size);
  if (should_fail()) { errno = ENOMEM; return NULL; }
  return real_realloc(ptr, size);
}

/* Arena memory is never returned: the arena is small, used only
   during bootstrap, and not worth a free list. */
void free(void *ptr) {
  if (ptr == NULL || from_arena(ptr)) return;
  init();
  if (real_free) real_free(ptr);
}

__attribute__((destructor))
static void report(void) {
  const char *path = getenv("ALLOC_COUNT_FILE");
  if (!path) return;
  FILE *f = fopen(path, "w");
  if (!f) return;
  fprintf(f, "%ld\n", counter);
  fclose(f);
}
