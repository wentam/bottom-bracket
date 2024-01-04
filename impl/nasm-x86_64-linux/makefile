all:
	nasm -g -f elf64 aarrp.asm
	nasm -g -f elf64 util.asm
	nasm -g -f elf64 reader.asm
	ld -o aarrp aarrp.o util.o reader.o
