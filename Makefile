CC = arm-none-eabi-gcc
AS = arm-none-eabi-as
CPU = -mcpu=cortex-m4 -mthumb -mfloat-abi=soft
LDFLAGS = -nostdlib -T bootloader/linker.ld
SRC_C = bootloader/main.c
SRC_S = bootloader/startup.s
OBJ = main.o startup.o
OUT = test.elf

# Optional optimization with OPT=1
ifeq ($(OPT),1)
    CFLAGS = $(CPU) -O3 -fno-builtin
else
    CFLAGS = $(CPU)
endif

all: $(OUT)

$(OUT): $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) $(LDFLAGS) -o $(OUT)

main.o: $(SRC_C)
	$(CC) $(CFLAGS) -c $(SRC_C) -o main.o

startup.o: $(SRC_S)
	$(AS) $(CPU) $(SRC_S) -o startup.o

clean:
	rm -f $(OUT) $(OBJ)
