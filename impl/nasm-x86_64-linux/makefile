.PHONY: release
release: NASMFLAGS:= -Ox
release: aarrp

.PHONY: debug
debug: NASMFLAGS := -DASSERT_STACK_ALIGNMENT -g
debug: aarrp

build/%.o: src/%.asm
	@mkdir -p build/
	nasm ${NASMFLAGS} -f elf64 $< -o $@

aarrp: build/aarrp.o build/util.o build/reader.o build/buffered_reader.o
	ld -o build/aarrp build/aarrp.o build/util.o build/reader.o build/buffered_reader.o

.PHONY: clean
clean:
	rm -r build
