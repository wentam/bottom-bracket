.PHONY: release
release: NASMFLAGS:= -Ox
release: aarrp

.PHONY: debug
debug: NASMFLAGS := -DASSERT_STACK_ALIGNMENT -g
debug: aarrp

build/%.o: src/%.asm
	@mkdir -p build/
	nasm ${NASMFLAGS} -f elf64 $< -o $@

aarrp: build/aarrp.o \
			build/util.o \
			 build/reader.o \
			 build/buffered_reader.o \
			 build/byte_buffer.o
	ld -o build/aarrp $?

.PHONY: clean
clean:
	rm -fr build
