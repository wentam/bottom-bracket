;;;; Registers:
;;;;
;;;; qword (64-bit): rax [rbx] rcx rdx rsp [rbp] rsi rdi r8  r9  r10  r11  [r12]  [r13]  [r14]  [r15]
;;;; dword (32-bit): eax [ebx] ecx edx esp [ebp] esi edi r8d r9d r10d r11d [r12d] [r13d] [r14d] [r15d]
;;;;  word (16-bit):  ax  [bx]  cx  dx  sp  [bp]  si  di r8w r9w r10w r11w [r12w] [r13w] [r14w] [r15w]
;;;;  byte  (8-bit):  al  [bl]  cl  dl spl [bpl] sil dil r8b r9b r10b r11b [r12b] [r13b] [r14b] [r15b]
;;;; [callee-preserve register]
;;;;
;;;; rsp: stack pointer
;;;;
;;;; Function arguments: rdi rsi rdx rcx r8 r9
;;;; Remaining arguments are passed on the stack in reverse order so that they
;;;; can be popped off the stack in order.
;;;;
;;;; callee preserve registers: rbp, rbx, r12, r13, r14, r15
;;;;
;;;; return value: rax
;;;;
;;;; Syscalls:
;;;; arguments: rdi rsi rdx r10 r8 r9. No stack arguments.
;;;; return value: rax. A value in the range between -4095 and -1 indicates an error
;;;;
;;;; syscalls clobbers rcx, r11, and rax. All other register are preserved.

section .text
global _start

;; TODO clean up unused externs, we use this spot as a testbed
;; so it gets messy

extern write
extern exit
extern write_char
extern read_char
extern malloc
extern malloc_cleanup
extern realloc
extern free
extern write_as_base
extern parse_uint
extern read
extern assert_stack_aligned
extern bindump
extern dump_read_result_buffer
extern dump_read_result
extern print
extern barray_equalp
extern dump_expand_count

extern init_macro_stacks
extern free_macro_stacks

extern macro_stack_reader
extern macro_stack_printer
extern macro_stack_structural

extern kv_stack_new
extern kv_stack_free
extern kv_stack_push
extern kv_stack_pop
extern kv_stack_peek
extern kv_stack_bindump_buffers
extern kv_stack_peek_by_key
extern kv_stack_pop_by_key
extern byte_buffer_delete_bytes
extern barray_new
extern parray_literal
extern ascii_to_digit
extern byte_buffer_new
extern structural_macro_expand_relptr
extern structural_macro_expand
extern byte_buffer_bindump_buffer
extern byte_buffer_free
extern _malloc
extern _free

extern hashmap_new
extern hashmap_free
extern hashmap_rehash
extern hashmap_get
extern hashmap_set
extern hashmap_rm

section .rodata

stdin_fd: equ 0
stdout_fd: equ 1
stderr_fd: equ 2

welcome_msg:      db  "Welcome!",10
welcome_msg_len:  equ $ - welcome_msg


readermac_msg: db 10,"Reader macro stack",10,"--------",10
readermac_msg_len: equ $ - readermac_msg

printermac_msg: db 10,"Printer macro stack",10,"--------",10
printermac_msg_len: equ $ - printermac_msg

structuralmac_msg: db 10,"Structural macro stack",10,"--------",10
structuralmac_msg_len: equ $ - structuralmac_msg

buffer_msg: db 10,"Read result backing buffer",10,"--------",10
buffer_msg_len: equ $ - buffer_msg

result_msg: db 10,"Read result",10,"--------",10
result_msg_len: equ $ - result_msg

print_msg: db 10,"Printed before macroexpansion",10,"--------",10
print_msg_len: equ $ - print_msg

print2_msg: db 10,"Printed after macroexpansion",10,"--------",10
print2_msg_len: equ $ - print2_msg

me_msg: db 10,"Macroexpanded backing buffer",10,"--------",10
me_msg_len: equ $ - me_msg

test_macro_name: db 3,0,0,0,0,0,0,0,"foo"
test_macro_code: db 11,0,0,0,0,0,0,0,"code-stuffs"

test_macro_name_2: db 3,0,0,0,0,0,0,0,"bar"
test_macro_code_2: db 11,0,0,0,0,0,0,0,"aaaaaaaaaaa"

test_macro_name_3: db 4,0,0,0,0,0,0,0,"fooo"

foo_key: dq 3,"foo"
foo2_key: dq 4,"foo2"

section .text


%define MAP_ANONYMOUS  0x20
%define MAP_PRIVATE    0x02
%define MAP_STACK      0x020000

%define PROT_READ      0x1
%define PROT_WRITE     0x2
%define PROT_EXEC      0x4

%define SYS_MMAP 9
%define SYS_MUNMAP 11

%define STACK_SIZE (128*1024*1024)

;; TODO: count allocations and warn if not everything has been freed at the end - or provide
;;       needed things for valgrind to work
;; TODO: utility to push all registers and utility to pop all registers,
;;       to make it easy to inject debugging functions in the middle of something
;; TODO: make sure we're handling all errors that could occur from syscalls
;; TODO: write_as_base isn't keeping the stack 16-aligned while making function calls
;; TODO: rather than error outright, the reader should generate error codes for things like
;;       unexpected EOF for us to handle here
;; TODO: reader macros should be able to expand into nothing by returning NULL
;; TODO: right now structural macro expansion and 'read' work in different ways: structural macro
;;       expansion expands into a byte buffer passed as an argument, while 'read' creates it's
;;       own buffer and returns a pointer. I think it should be possible to make this consistent,
;;       and if possible I think I prefer the 'read' approach as it masks the usage of byte buffer.
;;
;;       pay attention to what happens when a reader macro/structural macro expands into nothing.
_start:
  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Make ourselves a really big stack
  ;;
  ;; This is fine because the linux kernel lazy-allocates pages - we won't actually "consume"
  ;; this memory from the system unless we actually use it.
  ;;
  ;; This is just defensive: we do a lot of recursion in this codebase and this gives us
  ;; lots of extra space for doing that without worry.
  mov rbp, rsp

  mov rax, SYS_MMAP          ; sys_mmap
  mov rdi, 0                 ; addr (let kernel choose)
  mov rsi, STACK_SIZE        ; length
  mov rdx, (PROT_READ | PROT_WRITE)
  mov r10, (MAP_PRIVATE | MAP_ANONYMOUS | MAP_STACK)
  mov r8, -1                 ; fd
  mov r9, 0                  ; offset
  syscall

  mov r13, rax ; Pointer to free when we're done
  lea rsp, [rax + STACK_SIZE - 16]
  and rsp, ~15

  ;mov rdi, rsp
  ;call paint_stack

  call byte_buffer_new
  mov rdi, rax
  call byte_buffer_free

  call init_macro_stacks

  ;; TODO tmp START
  mov rdi, 16
  call hashmap_new
  mov r12, rax

  mov rdi, r12
  mov rsi, foo_key
  mov rdx, 1337
  call hashmap_set

  mov rdi, r12
  mov rsi, foo2_key
  mov rdx, 1337
  call hashmap_set

  mov rdi, r12
  call hashmap_rehash

  mov rdi, r12
  mov rsi, foo_key
  call hashmap_rm

  mov rdi, r12
  mov rsi, foo2_key
  call hashmap_get
  ;mov rdi, qword[rax]

  mov rdi, rax
  mov rsi, 10
  mov rdx, 2
  mov rcx, 0
  call write_as_base

  mov rdi, r12
  call hashmap_free
  ;; TODO tmp END

  ;; Make an arena for reader and macroexpander
  ;;
  ;; We can't share an arena because the reader uses absolute pointers.
  call byte_buffer_new
  mov rbx, rax
  call byte_buffer_new
  mov r14, rax

  ;; Read
  mov rdi, stdin_fd
  mov rsi, rbx
  call read
  mov r12, rax

  ;; Macroexpand
  mov rdi, r12
  mov rsi, r14
  mov rdx, 2 ; greedy expand
  mov rcx, 0
  call structural_macro_expand
  mov r15, rax

  ;; Print
  mov rdi, r15
  mov rsi, stdout_fd
  call print

  ;; Free our arenas
  mov rdi, rbx
  call byte_buffer_free
  mov rdi, r14
  call byte_buffer_free

  ;; Newline
  mov rdi, 10
  mov rsi, stderr_fd
  call write_char

  ;; Print out how many macros we expanded
  call dump_expand_count

  ;; Cleanup
  call free_macro_stacks
  call malloc_cleanup

  ;mov rdi, rsp
  ;call find_peek_stack_depth

  ;; Free our big stack
  mov rsp, rbp

  mov rdi, r13
  mov rsi, STACK_SIZE
  mov rax, SYS_MUNMAP
  syscall

  ;; Exit
  mov rdi, 0
  call exit

;; Some debug utils to measure stack usage

;; (rsp)
paint_stack:
  sub rdi, (7*1024*1024)      ; Start 7MB into the stack
  sub rdi, 32                 ; Don't paint the first bit to avoid stepping
                              ; on ourselves.
  mov rax, 0x0123456789ABCDEF
  mov rcx, ((7*1024*1024)/8)  ; Paint 7MB worth of stack
  rep stosq
  ret

find_peek_stack_depth:
  push r15
  mov r15, rdi
  ; rdi = start of stack
  mov rax, 0x0123456789ABCDEF
.scan_loop:
  sub rdi, 8
  cmp [rdi], rax
  je .found_boundary        ; Found overwritten canary
  jmp .scan_loop

.found_boundary:
  ; rdi now points to deepest stack usage
  mov rax, r15
  sub rax, rdi              ; Stack depth in bytes

  mov rdi, rax
  mov rsi, 10
  mov rdx, 2
  mov rcx, 0
  call write_as_base

  mov rdi, 10
  mov rsi, 2
  call write_char
  pop r15
  ret
