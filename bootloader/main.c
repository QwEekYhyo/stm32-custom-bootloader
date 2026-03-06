#include <stdint.h>

#define APP_ADDRESS 0x08004000

typedef void (*entry_t)(void);

int main(void) {
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
