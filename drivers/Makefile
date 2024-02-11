
#TARGETS=drivers.st
PROGS=extmod.prg

AS=vasmm68k_mot
ASOPT=-m68000 -Ftos -tos-flags=7 -nosym

all: $(TARGETS) $(PROGS)

clean:
	rm -f $(TARGETS) $(PROGS) *.o

%.st: $(PROGS)
	hmsa $@ SS
	sudo mount -oloop -tmsdos $@ /mnt
	sudo mkdir -p /mnt/auto
	sudo cp $^ /mnt/auto
	sudo umount /mnt

%.xz: %
	xz -f9 $<

%.prg: %.s
	$(AS) $(ASOPT) $< -o $@
