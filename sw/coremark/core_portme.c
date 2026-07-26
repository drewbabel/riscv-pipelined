/* CoreMark port (EEMBC barebones, Apache 2.0) */
#include "coremark.h"
#include "core_portme.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

#define EE_TICKS_PER_SEC CORE_CLK_HZ

static ee_u32
read_mcycle(void)
{
    ee_u32 c;
    __asm__ volatile("csrr %0, mcycle" : "=r"(c));
    return c;
}

static CORETIMETYPE start_time_val, stop_time_val;

void
start_time(void)
{
    start_time_val = read_mcycle();
}

void
stop_time(void)
{
    stop_time_val = read_mcycle();
}

CORE_TICKS
get_time(void)
{
    return (CORE_TICKS)(stop_time_val - start_time_val);
}

secs_ret
time_in_secs(CORE_TICKS ticks)
{
    return ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
}

ee_u32 default_num_contexts = 1;

void
portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
        ee_printf("ERROR! ee_ptr_int must hold a pointer!\n");
    if (sizeof(ee_u32) != 4)
        ee_printf("ERROR! ee_u32 must be a 32b unsigned type!\n");
    p->portable_id = 1;
}

void
portable_fini(core_portable *p)
{
    volatile unsigned int *stats = (unsigned int *)0x05000000;
    unsigned int ih = stats[0], im = stats[1], dh = stats[2], dm = stats[3];

    ee_printf("icache hits %u misses %u\n", ih, im);
    ee_printf("dcache hits %u misses %u\n", dh, dm);
    if (ih + im)
        ee_printf("icache hit rate %u/1000\n", (unsigned int)((ih * 1000ULL) / (ih + im)));
    if (dh + dm)
        ee_printf("dcache hit rate %u/1000\n", (unsigned int)((dh * 1000ULL) / (dh + dm)));

    p->portable_id = 0;
}
