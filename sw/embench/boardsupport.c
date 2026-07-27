#include <support.h>

#define UART_DATA  ((volatile unsigned int *) 0x04000000)
#define UART_READY ((volatile unsigned int *) 0x04000004)

static unsigned int start_cycle, stop_cycle;

static unsigned int read_mcycle(void) {
  unsigned int c;
  __asm__ volatile("csrr %0, mcycle" : "=r"(c));
  return c;
}

void initialise_board(void) {}

void __attribute__((noinline)) __attribute__((externally_visible)) start_trigger(void) {
  __asm__ volatile("" ::: "memory");
  start_cycle = read_mcycle();
}

void __attribute__((noinline)) __attribute__((externally_visible)) stop_trigger(void) {
  stop_cycle = read_mcycle();
  __asm__ volatile("" ::: "memory");
}

static void put_char(char c) {
  while (!(UART_READY[0] & 1u)) {
  }
  UART_DATA[0] = (unsigned int) (unsigned char) c;
}

static void put_str(const char *s) {
  while (*s) put_char(*s++);
}

static void put_uint(unsigned int v) {
  char buf[10];
  int n = 0;
  if (v == 0) {
    put_char('0');
    return;
  }
  while (v) {
    buf[n++] = (char) ('0' + v % 10u);
    v /= 10u;
  }
  while (n--) put_char(buf[n]);
}

void bench_report(int rc) {
  put_str(BENCH_NAME);
  put_str(" cycles ");
  put_uint(stop_cycle - start_cycle);
  put_str(rc ? " FAIL\n" : " OK\n");
}
