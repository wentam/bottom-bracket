rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2)) 
SRCS = $(call rwildcard,src/,*.asm)
OBJS = $(SRCS:src/%.asm=build/%.o)

ASM ?= nasm

.PHONY: release
release: ASMFLAGS := -Ox
release: STRIP := 1
release: build/bbr

.PHONY: debug
#debug: ASMFLAGS := -DASSERT_STACK_ALIGNMENT -g
debug: ASMFLAGS := -g
debug: build/bbr

PREFIX ?= /usr/local
DESTDIR ?=

.PHONY: install
install: release
	mkdir -p "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 build/bbr "$(DESTDIR)$(PREFIX)/bin"

.PHONY: uninstall
uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/bbr"

build/%.o: src/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) -f elf64 $< -o $@

build/bbr: ${OBJS}
	ld -o $@ $^ -z noexecstack
	if [ $(STRIP) ]; then strip $@; fi

.PHONY: clean
clean:
	rm -fr build
