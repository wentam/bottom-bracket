all:
	nasm -g -f elf64 aarrp.asm
	nasm -g -f elf64 util.asm
	nasm -g -f elf64 reader.asm
	nasm -g -f elf64 buffered_reader.asm
	ld -o aarrp aarrp.o util.o reader.o buffered_reader.o

clean:
	rm *.o
	rm aarrp
