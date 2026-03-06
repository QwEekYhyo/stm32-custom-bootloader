#include <stdint.h>

#define APP_ADDRESS 0x08004000

typedef void (*entry_t)(void);

int main(void) {
    // Enable RCC for GPIOB
    *((volatile uint32_t*) 0x4002104C) |= 1 << 1;

    // Enable RCC for SYSCFG
    *((volatile uint32_t*) 0x40021060) |= 1 << 0;

    // Set PB8 as output (0b01)
    *((volatile uint32_t*) 0x48000400) |= 1 << 16;
    *((volatile uint32_t*) 0x48000400) &= ~(1 << 17);

    // Turn on LED
    *((volatile uint32_t*) 0x48000414) |= 1 << 8;

    // Get app stack pointer
    uint32_t stack = *(volatile uint32_t*)APP_ADDRESS;

    // Get app reset handler
    uint32_t rh = *(volatile uint32_t*)(APP_ADDRESS + 4);
    entry_t reset_handler = (entry_t)rh;

    // Disable IRQ interrupts
    asm ("cpsid i"); // this is Change Processor State instruction

    // Set stack pointer
    asm volatile ("msr msp, %0"
            : /* no outputs */
            : "r" (stack)
            : /* no clobbers */ );

    reset_handler();

    for (;;);
}
