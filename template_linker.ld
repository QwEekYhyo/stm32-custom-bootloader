/* I don't know if anything else is supported so we'll use this and this only */
OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")

/* Set entry point */
ENTRY(Reset_Handler)

/* Memory sizes */
FLASH_SIZE = 0x20000;   /* 128 KiB = 131,072 bytes */
SRAM_SIZE = 0x8000;     /* 32 KiB = 32,768 bytes */
MIN_STACK_SIZE = 0x400; /* 1 KiB = 1024 bytes */
/* I don't plan on calling malloc but whatever */
MIN_HEAP_SIZE = 0x200   /* 512 bytes */

/* Define memory space */
MEMORY
{
    /* RAM needs to be rwx if using RamFunc */
    RAM   (rw) : ORIGIN = 0x20000000, LENGTH = SRAM_SIZE
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = FLASH_SIZE
}

/* Top of the stack, the stack grows down */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* The sections may need to be completed with some stuff like init, fini, eh_frame, init_array, fini_array */
SECTIONS
{
    /* Vector table is expected to be first */
    .isr_vector :
    {
        /* Align to next 4-byte boundary because vector table is an array of 32-bit addresses, we should already be aligned but for safety */
        . = ALIGN(4);
        /* Keep the isr_vector symbol defined in startup code and place it here */
        KEEP(*(.isr_vector))
    } >FLASH

    /* Code essentially */
    .text :
    {
        /* Add all text sections from other object files */
        . = ALIGN(4);
        *(.text)
        *(.text*)

        /* Create a symbol marking the end of code */
        . = ALIGN(4);
        _etext = .;
    } >FLASH

    /* Read-only data */
    .rodata :
    {
        /* Add all rodata sections from other object files */
        . = ALIGN(4);
        *(.rodata)
        *(.rodata*)
    } >FLASH

    /* Initialized global and static symbols */
    /* Will live in RAM at runtime but initial values are stored in Flash */
    .data :
    {
        . = ALIGN(4);
        /* Create a symbol marking the start of data */
        _sdata = .;
        *(.data)
        *(.data*)
        /* Maybe I would need to add RamFunc?? */

        /* Create a symbol marking the end of data */
        . = ALIGN(4);
        _edata = .;
    } >RAM AT> FLASH

    /* Uninitialized data */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        	
        . = ALIGN(4);
        _ebss = .;
    } >RAM

    /* Comes from Cube and not actually used, it's just there to check that there is enough RAM type memory */
    ._user_heap_stack :
    {
        . = ALIGN(8);
        PROVIDE ( end = . );
        PROVIDE ( _end = . );
        . = . + MIN_HEAP_SIZE;
        . = . + MIN_STACK_SIZE;
    } >RAM

    /* Remove comment section and lib lines come from Cube */
    /DISCARD/ :
    {
        *(.comment)
        libc.a ( * )
        libm.a ( * )
        libgcc.a ( * )
    }
}
