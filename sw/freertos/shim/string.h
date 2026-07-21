#ifndef SHIM_STRING_H
#define SHIM_STRING_H
#include <stddef.h>
void  *memset(void *d, int c, size_t n);
void  *memcpy(void *d, const void *s, size_t n);
int    memcmp(const void *a, const void *b, size_t n);
char  *strcpy(char *d, const char *s);
size_t strlen(const char *s);
#endif
