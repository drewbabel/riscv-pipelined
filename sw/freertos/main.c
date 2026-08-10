#include <stdint.h>

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define LED (*(volatile unsigned int *) 0x03000000)
#define SW  (*(volatile unsigned int *) 0x03000004)
#define UART_TX (*(volatile unsigned int *) 0x04000000)
#define UART_ST (*(volatile unsigned int *) 0x04000004)
#define CORE_CLK_HZ (*(volatile unsigned int *) 0x05000010)

/* Replaces kernel copy */
size_t uxTimerIncrementsForOneTick = 0;

extern uint64_t ullNextTime;
extern volatile uint64_t *pullMachineTimerCompareRegister;

/* Overrides weak version */
void vPortSetupTimerInterrupt(void) {
  volatile uint32_t *const time_hi = (volatile uint32_t *) (configMTIME_BASE_ADDRESS + 4UL);
  volatile uint32_t *const time_lo = (volatile uint32_t *) configMTIME_BASE_ADDRESS;
  uint32_t now_hi, now_lo;

  uxTimerIncrementsForOneTick = (size_t) (CORE_CLK_HZ / configTICK_RATE_HZ);
  pullMachineTimerCompareRegister = (volatile uint64_t *) configMTIMECMP_BASE_ADDRESS;

  do {
    now_hi = *time_hi;
    now_lo = *time_lo;
  } while (now_hi != *time_hi);

  ullNextTime = ((uint64_t) now_hi << 32) | (uint64_t) now_lo;
  ullNextTime += (uint64_t) uxTimerIncrementsForOneTick;
  *pullMachineTimerCompareRegister = ullNextTime;
  ullNextTime += (uint64_t) uxTimerIncrementsForOneTick;
}

static void uart_putc(char c) {
  while (!(UART_ST & 1)) {
  }
  UART_TX = c;
}

#ifndef READ_DELAY
#define READ_DELAY pdMS_TO_TICKS(20)
#endif

static QueueHandle_t sw_queue;

static void switch_reader(void *pv) {
  (void) pv;
  for (;;) {
    unsigned int pattern = SW & 0xFFFF;
    xQueueSend(sw_queue, &pattern, portMAX_DELAY);
    vTaskDelay(READ_DELAY);
  }
}

static void led_writer(void *pv) {
  (void) pv;
  unsigned int pattern;
  for (;;) {
    if (xQueueReceive(sw_queue, &pattern, portMAX_DELAY) == pdTRUE) {
      LED = pattern;
      uart_putc("0123456789ABCDEF"[pattern & 0xF]);
    }
  }
}

int main(void) {
  LED = 0x0200;  // entered main
  sw_queue = xQueueCreate(4, sizeof(unsigned int));
  LED = 0x0300;  // queue created
  xTaskCreate(switch_reader, "rd", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
  xTaskCreate(led_writer, "wr", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
  vTaskStartScheduler();
  for (;;) {
  }
}

void vApplicationMallocFailedHook(void) {
  for (;;) {
  }
}
