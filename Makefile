ASM = nasm

%.o: %.asm
	${ASM} -felf64 $< -o $@
boot: kernel.o entry.o linker.ld
	ld -T linker.ld -o boot entry.o kernel.o
isodir:
	mkdir -p isodir/boot/grub
boot.iso: boot isodir
	cp boot isodir/boot/kernel
	grub2-mkrescue -o boot.iso isodir
	#cp vga isodir/boot/vga.bin
