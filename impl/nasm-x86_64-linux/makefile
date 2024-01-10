rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2)) 
SRCS = $(call rwildcard,src/,*.asm)
OBJS = $(SRCS:src/%.asm=build/%.o)

.PHONY: release
release: NASMFLAGS:= -Ox
release: aarrp

.PHONY: debug
debug: NASMFLAGS := -DASSERT_STACK_ALIGNMENT -g
debug: aarrp

build/%.o: src/%.asm
	@mkdir -p build/
	nasm ${NASMFLAGS} -f elf64 $< -o $@

aarrp: ${OBJS}
	ld -o build/aarrp $?

.PHONY: clean
clean:
	rm -fr build
