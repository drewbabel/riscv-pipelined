#include <stddef.h>

void *memset(void *d, int c, size_t n) {
  unsigned char *p = d;
  while (n--) *p++ = (unsigned char) c;
  return d;
}

void *memcpy(void *d, const void *s, size_t n) {
  unsigned char *pd = d;
  const unsigned char *ps = s;
  while (n--) *pd++ = *ps++;
  return d;
}

void *memmove(void *d, const void *s, size_t n) {
  unsigned char *pd = d;
  const unsigned char *ps = s;
  if (pd < ps) {
    while (n--) *pd++ = *ps++;
  } else {
    pd += n;
    ps += n;
    while (n--) *--pd = *--ps;
  }
  return d;
}

int memcmp(const void *a, const void *b, size_t n) {
  const unsigned char *pa = a, *pb = b;
  while (n--) {
    if (*pa != *pb) return (int) *pa - (int) *pb;
    pa++;
    pb++;
  }
  return 0;
}

char *strcpy(char *d, const char *s) {
  char *r = d;
  while ((*d++ = *s++)) {
  }
  return r;
}

char *strchr(const char *s, int c) {
  for (;; s++) {
    if (*s == (char) c) return (char *) s;
    if (!*s) return NULL;
  }
}

int strcmp(const char *a, const char *b) {
  while (*a && *a == *b) {
    a++;
    b++;
  }
  return (int) (unsigned char) *a - (int) (unsigned char) *b;
}

int strncmp(const char *a, const char *b, size_t n) {
  while (n && *a && *a == *b) {
    a++;
    b++;
    n--;
  }
  if (!n) return 0;
  return (int) (unsigned char) *a - (int) (unsigned char) *b;
}

size_t strlen(const char *s) {
  const char *p = s;
  while (*p) p++;
  return (size_t) (p - s);
}

int abs(int v) { return v < 0 ? -v : v; }

double fabs(double v) { return v < 0.0 ? -v : v; }

float fabsf(float v) { return v < 0.0f ? -v : v; }

// newton raphson
double sqrt(double v) {
  double x;
  int i;
  if (v <= 0.0) return 0.0;
  x = v;
  for (i = 0; i < 40; i++) x = 0.5 * (x + v / x);
  return x;
}

int isdigit(int c) { return c >= '0' && c <= '9'; }

int isxdigit(int c) {
  return isdigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

int isspace(int c) { return c == ' ' || (c >= 9 && c <= 13); }

int isalpha(int c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

int isalnum(int c) { return isalpha(c) || isdigit(c); }

int tolower(int c) { return (c >= 'A' && c <= 'Z') ? c + 32 : c; }

int toupper(int c) { return (c >= 'a' && c <= 'z') ? c - 32 : c; }

int printf(const char *fmt, ...) {
  (void) fmt;
  return 0;
}

int puts(const char *s) {
  (void) s;
  return 0;
}

void abort(void) {
  for (;;) {
  }
}

void exit(int status) {
  (void) status;
  for (;;) {
  }
}
