TARGET   = blinky

# ── Directory layout ──
SRCDIR   = src
LINKDIR  = linker
TOOLSDIR = tools
LIBDIR   = lib
BUILDDIR = build
BINDIR   = bin

# ── Source files ──
SRC      = $(SRCDIR)/main.c
LDSCRIPT = $(LINKDIR)/link.ld

# ── Host tools ──
COMPCRC_SRC = $(TOOLSDIR)/compCrc32.cpp
COMPCRC_BIN = $(BUILDDIR)/compCrc32.out
UF2CONV     = $(LIBDIR)/uf2/utils/uf2conv.py

# ── Toolchain ──
TOOLCHAIN = arm-none-eabi-
CC        = $(TOOLCHAIN)gcc
OBJDUMP   = $(TOOLCHAIN)objdump
OBJCOPY   = $(TOOLCHAIN)objcopy
HOSTCXX   = g++

# ── Flags ──
CFLAGS  = -mcpu=cortex-m0plus -Wall -Wno-main
LDFLAGS = -T $(LDSCRIPT) -nostdlib

# ── RP2040 UF2 settings ──
FLASH_BASE   = 0x10000000
UF2_FAMILY   = 0xe48bff56

# ── Pico mount point (set to your system's path) ──
PICO_MOUNT  ?= /run/media/$(USER)/RPI-RP2

# ============================================================
#  Build targets
# ============================================================

.PHONY: all clean flash

all: $(BINDIR)/$(TARGET).uf2
	@echo "  Build complete: $(BINDIR)/$(TARGET).uf2"

# ── Create output directories ──
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

# ── Step 1: Compile to object (for CRC calculation) ──
$(BUILDDIR)/$(TARGET)_temp.o: $(SRC) | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# ── Step 2: Raw binary of the object (for CRC input) ──
$(BUILDDIR)/$(TARGET)_temp.bin: $(BUILDDIR)/$(TARGET)_temp.o
	$(OBJCOPY) -O binary $< $@

# ── Step 3: Build the host CRC32 tool ──
$(COMPCRC_BIN): $(COMPCRC_SRC) | $(BUILDDIR)
	$(HOSTCXX) -I $(LIBDIR) $< -o $@

# ── Step 4: Compute CRC and generate crc.c ──
$(BUILDDIR)/crc.c: $(BUILDDIR)/$(TARGET)_temp.bin $(COMPCRC_BIN)
	./$(COMPCRC_BIN) $<

# ── Step 5: Link everything (source + generated crc.c) ──
$(BUILDDIR)/$(TARGET).elf: $(SRC) $(BUILDDIR)/crc.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

# ── Step 6: ELF → raw binary ──
$(BUILDDIR)/$(TARGET).bin: $(BUILDDIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# ── Step 7: Binary → UF2 ──
$(BUILDDIR)/$(TARGET).uf2: $(BUILDDIR)/$(TARGET).bin
	python3 $(UF2CONV) -b $(FLASH_BASE) -f $(UF2_FAMILY) -c $< -o $@

# ── Step 8: Copy final UF2 to bin/ (survives make clean) ──
$(BINDIR)/$(TARGET).uf2: $(BUILDDIR)/$(TARGET).uf2 | $(BINDIR)
	cp $< $@

# ── Disassembly ──
disasm: $(BUILDDIR)/$(TARGET).elf
	$(OBJDUMP) -hSD $< > $(BUILDDIR)/$(TARGET).objdump
	@echo "Disassembly saved to $(BUILDDIR)/$(TARGET).objdump"

# ── Flash: copy UF2 to Pico in BOOTSEL mode ──
flash: $(BINDIR)/$(TARGET).uf2
	@if [ -d "$(PICO_MOUNT)" ]; then \
		cp $< $(PICO_MOUNT)/ && echo "Flashed to Pico!"; \
	else \
		echo "Error: Pico not found at $(PICO_MOUNT)"; \
		echo "Hold BOOTSEL and plug in the Pico, then retry."; \
		exit 1; \
	fi

# ── Clean ──
clean:
	rm -rf $(BUILDDIR)