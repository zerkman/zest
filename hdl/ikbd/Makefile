TARGETS=ikbd_rom.mem

all: $(TARGETS)

%.bin: %.s
	a09 -b$@ -oh01 $<

%.mem: %.bin
	od -vt x1 ikbd_rom.bin | sed -e 's/^[^ ]* //' | head -n -1 > $@
