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

size_t strlen(const char *s) {
  const char *p = s;
  while (*p) p++;
  return (size_t) (p - s);
}

double modf(double value, double *iptr) {
  long long ip = (long long) value;
  *iptr = (double) ip;
  return value - (double) ip;
}
