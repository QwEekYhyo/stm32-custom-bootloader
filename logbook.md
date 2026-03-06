# Initial questions

- **what does a bootloader do exactly? (in the case of an MCU)**
  => a lot less than an OS loader (typically what is referred to when talking about bootloader).
     checks if user is trying to update the firmware, if so it updates the firmware and if not it boots the current firmware.
     jumping to application seem to mean: read app stack pointer and reset handler, then disable interrupts because app and bootloader have different ISR vector and we don't want interrupts to be fired during the transition, maybe relocate vector table to the app's vector table, maybe disable some other things the bootloader enabled and then set the main stack pointer to the app stack pointer and finally call the app reset handler.

- **where does it live?**
  => in the flash memory, where the normal program is. kinda like GRUB lives on the drive where the OS also lives.
     there can be other bootloaders living somewhere else like in ROM on some STM32s kinda like you would have a BIOS or UEFI in a flash chip soldered on the motherboard, that's shipped with the PC and cannot be easily rewritten (and without dangers).
where in flash? two possibilities:
at the start of the flash (address near 0) /
at the end of the flash.
**start** => easier to write the bootloader as this is where normal apps are booted from.
**end** => more flexible as firmware writes to flash unaware of the custom bootloader will not overwrite it (as apps are supposed to be at the start) and apps not at the start would not boot without the custom bootloader.

- **how is it different from any normal program?**
    => it seems not to be

- **how is it started?**
    => somehow automatically after reset, in the same way the app would start after reset with no custom bootloader.

- **how does it receives the new firmware?**
    => it must be started before the normal program, it will check for a signal to enter "update mode" and if no signal is received it will jump to the normal program.
```c
if (update_requested()) {
    enter_update_mode();
} else {
    jump_to_application();
}
```
this signal could be for example received via UART, so the bootloader waits on UART, if there is communication then -> update mode, if there is none then -> app.
But it could be any protocol, even wireless ones or it could even be searching for a firmware on a file system like a USB stick or an SD card.
In any case, this would require some computer side app (maybe not if using file system updates).


# Follow up questions

**What are the possible features for a custom bootloader?**

- Over The Air updates
- Secure boot
- Flash encryption
- Integrity check
- Version management
- Dual Firmware Slot
- Firmware rollback
- Flash protection check
- Secure debug control
- Delta updates (diff patching)
- Firmware compression
- Multi image (choose your OS type of thing or images that depend on each other and require a certain version of the other)
- Update another MCU
- Update simulation mode (bootloader does everything like normal but doesn't write to flash, so it just validates the image and etc...)

And much more

# Links

- [https://www.codeproject.com/articles/Writing-A-Bootloader](https://www.codeproject.com/articles/Writing-A-Bootloader)
- [https://controllerstech.com/stm32-custom-bootloader-tutorial/](https://controllerstech.com/stm32-custom-bootloader-tutorial/)
- [https://interrupt.memfault.com/blog/how-to-write-a-bootloader-from-scratch](https://interrupt.memfault.com/blog/how-to-write-a-bootloader-from-scratch)
- [https://stackoverflow.com/questions/74840491/advice-on-writing-a-custom-bootloader-for-stm32-mcu](https://stackoverflow.com/questions/74840491/advice-on-writing-a-custom-bootloader-for-stm32-mcu)
- [https://www.reddit.com/r/embedded/comments/n3caxu/writing_bootloaders_for_microcontrollers/](https://www.reddit.com/r/embedded/comments/n3caxu/writing_bootloaders_for_microcontrollers/)
- [https://github.com/akospasztor/stm32-bootloader](https://github.com/akospasztor/stm32-bootloader)
- [https://github.com/STMicroelectronics/stm32l5-openbl-apps](https://github.com/STMicroelectronics/stm32l5-openbl-apps)
- [https://github.com/STMicroelectronics/stm32-mw-openbl?tab=readme-ov-file](https://github.com/STMicroelectronics/stm32-mw-openbl?tab=readme-ov-file)
- [https://blog.thea.codes/the-most-thoroughly-commented-linker-script/](https://blog.thea.codes/the-most-thoroughly-commented-linker-script/)
- [https://ampheoelectronic.wordpress.com/2025/10/23/how-do-i-change-stack-pointer-in-stm32h743/](https://ampheoelectronic.wordpress.com/2025/10/23/how-do-i-change-stack-pointer-in-stm32h743/)
- [https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html)

# Development
## Setup

I had 3 boards at my disposal:
- A Chinese Arduino Uno R3 with an ATmega 328P MCU (32KB of Flash memory)
- An STM32 Nucleo G431KB with an MCU of the same name (128KB of Flash memory)
- An STM32 Nucleo H563ZI with an MCU of the same name (2MB of Flash memory)

So I chose to use an STM32 board because you see a lot of Tinkerer/DIY hacker do stuff with Arduino boards but seeing some ST boards is less common so I thought this would make this project more interesting. And I chose to use the G431KB because the H563ZI is a very powerful board, it's a little bit overkill in my opinion as you don't see a lot of boards with that much flash and also I will probably use it in another project as it has an ethernet port and I plan on doing things with that.

We will see how true this will stay during development but I plan on doing this without using much of the STM32 tools (most notably the Cube suite and the HAL library) so that it's as much from scratch as possible. This means I will manually write to registers and I will use OpenOCD to flash the program onto the MCU.

## Step 1

I plan on placing the bootloader at the end of memory addresses so that for now I can still easily use the ST-Link to flash the application (at the start of memory). For step 1, the bootloader will be as simple as possible so it will not even write to flash (hence the use of the ST-Link) it will simply jump to the application. But just so I can see the bootloader in action, before doing so it will turn on an LED and then the actual program will wait for a certain amount of time (so I can see the LED turned on by the bootloader) and then will make the LED blink.

This will be a good proof of concept as I will have two different programs living far away from each other in the flash at the same time and the bootloader will somewhat do its job of loading the next program.

I have 128KB of Flash to work with and I quickly looked at the size of a very simple STM32 program I had previously used to have an idea of the size firmwares have:
```sh
$ arm-none-eabi-size test.elf      
   text	   data	    bss	    dec	    hex	filename
    512	    460	      8	    980	    3d4	test.elf
```
This application uses almost 1KB which is less than 1% of our 128KB but as I said this is an extremely simple program so that was to be expected, so in prevision for a lot of cool features for my bootloader I thought that 16KiB would be a good amount to reserve. That leaves us with 112KiB for possible applications.

## Step 0

Step 0 is a preliminary step before step 1 because I just changed my mind and will first place the bootloader at the **start** of flash memory and the application right after. So the addresses and sizes are different here than the final version.

Pretty important discovery: the G431KB flash is divided into 2KiB pages and you can only write page by page, so addresses have to be multiple of 2K (or 0x800).

But I finally got this working!! I wrote a basic bootloader from scratch with its linker script, the startup code in assembly and a basic main function that only jumps to the application (TODO: link commit to browse code). I then created a basic app, not from scratch for now but using CubeIDE, I wrote a very basic blinky. At first all of this wouldn't work, for some reason the LED would turn ON but not blink, so I tried to remove the `HAL_Delay()` I was using to blink the LED, I replaced it with a simple nested loop that does nothing to introduce a delay and it seemed to be the problem. I don't really understand why for now but probably because of some thing that is not properly initialized to get ticks or whatever.

So to test it was actually doing its bootloader thing, here is what I did:

I first copied the ELF generated by Cube into a raw binary (openocd can flash ELFs but whatever, I didn't want to encounter issues because of this):
```sh
arm-none-eabi-objcopy -O binary blinky.elf ~/dev/bootloader/blinky.bin
```

Then, I declared the paths to the ST OpenOCD config files (not very important):
```sh
export STLINK_CONFIG=/usr/share/openocd/scripts/interface/stlink.cfg
export MCU_CONFIG=/usr/share/openocd/scripts/target/stm32g4x.cfg
```

Then I would erase the sectors in flash I was about to use:
```sh
openocd -f $STLINK_CONFIG -f $MCU_CONFIG -c "init; reset halt; flash erase_address 0x08000000 0x5800; exit"
```

At this point the STM32 does nothing as there is no valid program to run. Then flash the application image (blinky) at address 0x08004000:
```sh
# The erase is unnecessary as I already erased the flash
openocd -f $STLINK_CONFIG -f $MCU_CONFIG -c "init; reset halt; flash write_image erase blinky.bin 0x08004000; exit"
```

Now at this point there is technically a valid program in the flash but not where the MCU expects it, it cannot find a valid ISR vector so the STM32 should still do nothing, which I tested by resetting it. Then I could try to flash my bootloader at address 0x08000000:
```sh
openocd -f $STLINK_CONFIG -f $MCU_CONFIG -c "init; reset halt; flash write_image erase bootloader.bin 0x08000000; exit"
```

And just to visualize the two firmwares living in the flash, I did a flash dump of the flash I used and compared it to the hexdump of both binaries:
```sh
openocd -f $STLINK_CONFIG -f $MCU_CONFIG -c "init; reset halt; dump_image dump.bin 0x08000000 0x5800; exit"
hexdump -C dump.bin | less
```
I could clearly see the same hexdump as my bootloader at offset 0 in the image dump and the hexdump of the blinky application at offset 4000. And when I reset the STM32 it was now blinking the LED! Even though I technically did not add the blinky program with the last step but rather the program jumping to the blinky program.

| dump.bin | bootloader.bin |
|----------|----------------|
|00000000  ... m...........| 00000000    ... m...........|
|00000010  ................| 00000010    ................|
|00000020  ................| 00000020    ................|
|00000030  ................| 00000030    ................|
|00000040  .......K.h.`.K.h| 00000040    .......K.h.`.K.h|
|00000050  .`.h{`r..h....{h| 00000050    .`.h{`r..h....{h|
|00000060  .G...@...@...H.I| 00000060    .G...@...@...H.I|
|00000070  .J.B....P..;A..;| 00000070    .J.B....P..;A..;|
|00000080  ...H.I.".B....@.| 00000080    ...H.I.".B....@.|
|00000090  .+..............| 00000090    .+..............|
|000000a0  ... ... ... ... | 000000a0    ... ... ... ... |
|000000b0  ................| 000000b0    ....|
|000000c0  ................| 000000b4 |

| dump.bin | blinky.bin |
|----------|----------------|
|00004000    ... YD...C...C..| 00000000    ... YD...C...C..|
|00004010    .C...C...C......| 00000010    .C...C...C......|
|00004020    .............C..| 00000020    .............C..|
|00004030    .D.......D..'D..| 00000030    .D.......D..'D..|
|00004040    .D...D...D...D..| 00000040    .D...D...D...D..|
|*                           | *                           |
|00004080    .D.......D...D..| 00000080    .D.......D...D..|
|00004090    .D...D...D...D..| 00000090    .D...D...D...D..|
|*                           | *                           |
|000040f0    .D...D...D......| 000000f0    .D...D...D......|
|00004100    .....D.......D..| 00000100    .....D.......D..|
|00004110    .D.......D...D..| 00000110    .D.......D...D..|
|00004120    .D...D...D...D..| 00000120    .D...D...D...D..|
|00004130    .D...........D..| 00000130    .D...........D..|
|00004140    .D...D..........| 00000140    .D...D..........|

I only put the ASCII representation here as I thought this would be more visual than hexadecimal values. Blinky is a lot bigger than that (5.7 KB) but I only showed the first few lines. The bootloader was fully shown though, it's very small (180 bytes) because it doesn't use anything from the HAL and everything and it does very few things.
