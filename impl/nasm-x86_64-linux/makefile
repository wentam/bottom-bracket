rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2)) 
SRCS = $(call rwildcard,src/,*.asm)
OBJS = $(SRCS:src/%.asm=build/%.o)

.PHONY: release
release: NASMFLAGS:= -Ox
release: build/aarrp

.PHONY: debug
debug: NASMFLAGS := -DASSERT_STACK_ALIGNMENT -g
debug: build/aarrp

build/%.o: src/%.asm
	@mkdir -p build/
	nasm ${NASMFLAGS} -f elf64 $< -o $@

build/aarrp: ${OBJS}
	ld -o build/aarrp $^

.PHONY: clean
clean:
	rm -fr build
