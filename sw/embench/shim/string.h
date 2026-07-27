#ifndef SHIM_STRING_H
#define SHIM_STRING_H
#include <stddef.h>
void  *memset(void *d, int c, size_t n);
void  *memcpy(void *d, const void *s, size_t n);
void  *memmove(void *d, const void *s, size_t n);
int    memcmp(const void *a, const void *b, size_t n);
char  *strcpy(char *d, const char *s);
char  *strchr(const char *s, int c);
int    strcmp(const char *a, const char *b);
int    strncmp(const char *a, const char *b, size_t n);
size_t strlen(const char *s);
#endif
