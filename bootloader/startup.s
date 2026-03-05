.syntax unified
.cpu cortex-m4
.fpu softvfp    /* The G431KB has a single-precision floating-point unit */
.thumb

.global g_pfnVectors
.global	Default_Handler
.global	Reset_Handler

/* External symbols from linker */
.extern main
.extern _estack
.extern _sidata
.extern _sdata
.extern _edata
.extern _sbss
.extern _ebss

/* Reset Handler */
.section .text.Reset_Handler
.type Reset_Handler, %function

Reset_Handler:

    /* Copy .data from FLASH to RAM */

    ldr r0, =_sidata      /* source (Flash) */
    ldr r1, =_sdata       /* destination start (RAM) */
    ldr r2, =_edata       /* destination end (RAM) */

copy_data:
    cmp r1, r2            /* compare current RAM pointer with end of .data */
    bcc copy_word         /* if r1 < r2, branch to copy_word */
    b clear_bss_init      /* otherwise, finished copying -> clear .bss */

copy_word:
    ldr r3, [r0], #4      /* load 32-bit word from [r0] into r3, then offset r0 by 4 */
    str r3, [r1], #4      /* store r3 into [r1], then offset r1 by 4 */
    b copy_data           /* repeat the copy loop */

clear_bss_init:
    ldr r0, =_sbss        /* r0 = start address of .bss section in RAM */
    ldr r1, =_ebss        /* r1 = end address of .bss section in RAM */
    movs r2, #0           /* r2 = 0 (value used to zero memory) */

clear_loop:
    cmp r0, r1            /* compare current .bss pointer with end */
    bcc clear_word        /* if r0 < r1, branch to clear_word */
    b call_main           /* otherwise, .bss fully cleared -> call main */

clear_word:
    str r2, [r0], #4      /* store 0 into [r0], then offset r0 by 4 */
    b clear_loop          /* repeat zeroing loop */

call_main:
    bl main               /* branch with link to main (stores return address in LR) */

infinite_loop:
    b infinite_loop       /* infinite loop if main ever returns */

.size Reset_Handler, . - Reset_Handler


/* Default interrupt handler */
.section .text.Default_Handler
.type Default_Handler, %function

Default_Handler:
    b .

.size Default_Handler, . - Default_Handler


/* Vector Table */
.section .isr_vector, "a", %progbits
.type g_pfnVectors, %object

g_pfnVectors:
    .word _estack
    .word Reset_Handler
    .word NMI_Handler
    .word HardFault_Handler
    .word MemManage_Handler
    .word BusFault_Handler
    .word UsageFault_Handler
    .word 0
    .word 0
    .word 0
    .word 0
    .word SVC_Handler
    .word DebugMon_Handler
    .word 0
    .word PendSV_Handler
    .word SysTick_Handler

    /* Not all IRQ handlers are here */

.size g_pfnVectors, . - g_pfnVectors

/*******************************************************************************
*
* Provide weak aliases for each Exception handler to the Default_Handler.
* As they are weak aliases, any function with the same name will override
* this definition.
*
*******************************************************************************/

    .weak      NMI_Handler
    .thumb_set NMI_Handler,        Default_Handler

    .weak      HardFault_Handler
    .thumb_set HardFault_Handler,  Default_Handler

    .weak      MemManage_Handler
    .thumb_set MemManage_Handler,  Default_Handler

    .weak      BusFault_Handler
    .thumb_set BusFault_Handler,   Default_Handler

    .weak      UsageFault_Handler
    .thumb_set UsageFault_Handler, Default_Handler

    .weak      SVC_Handler
    .thumb_set SVC_Handler,        Default_Handler

    .weak      DebugMon_Handler
    .thumb_set DebugMon_Handler,   Default_Handler

    .weak      PendSV_Handler
    .thumb_set PendSV_Handler,     Default_Handler

    .weak      SysTick_Handler
    .thumb_set SysTick_Handler,    Default_Handler
