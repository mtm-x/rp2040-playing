TARGET  = blinky
SRC     = src/main.c
LDSCRIPT = linker/link.ld

CC      = arm-none-eabi-gcc
CFLAGS  = -mcpu=cortex-m0plus -Wall -Wno-main
LDFLAGS = -T $(LDSCRIPT) -nostdlib
UF2CONV = lib/uf2/utils/uf2conv.py

.PHONY: all clean flash disasm

all: build/$(TARGET).uf2
	@mkdir -p bin
	@cp $< bin/$(TARGET).uf2
	@echo "Build complete: bin/$(TARGET).uf2"

build/$(TARGET).uf2: $(SRC) tools/compCrc32.cpp
	@mkdir -p build
	$(CC) $(CFLAGS) -c $(SRC) -o build/temp.o
	arm-none-eabi-objcopy -O binary build/temp.o build/temp.bin
	g++ -I lib tools/compCrc32.cpp -o build/compCrc32.out
	./build/compCrc32.out build/temp.bin
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRC) build/crc.c -o build/$(TARGET).elf
	arm-none-eabi-objcopy -O binary build/$(TARGET).elf build/$(TARGET).bin
	python3 $(UF2CONV) -b 0x10000000 -f 0xe48bff56 -c build/$(TARGET).bin -o $@

disasm: build/$(TARGET).uf2
	arm-none-eabi-objdump -hSD build/$(TARGET).elf > build/$(TARGET).objdump

flash: bin/$(TARGET).uf2
	cp $< /run/media/$(USER)/RPI-RP2/ && echo "Flashed!"

clean:
	rm -rf build