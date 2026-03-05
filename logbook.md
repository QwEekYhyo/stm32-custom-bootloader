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

Step 0 is a preliminary step before step 1 because I just changed my mind and will first place the bootloader at the **start** of flash memory and the application right after.
