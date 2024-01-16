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
;;;; The only "non-special" registers are r10 r11.
;;;;
;;;; Syscalls:
;;;; arguments: rdi rsi rdx r10 r8 r9. No stack arguments.
;;;; return value: rax. A value in the range between -4095 and -1 indicates an error
;;;;
;;;; syscalls clobbers rcx, r11, and rax. All other register are preserved.

section .text
global _start
extern fn_write
extern fn_exit
extern fn_write_char
extern fn_read_char
extern fn_malloc
extern fn_realloc
extern fn_free
extern fn_write_as_base
extern fn_read
extern fn_assert_stack_aligned
extern fn_bindump
extern fn_free_read_result
extern fn_dump_read_result_buffer
extern fn_dump_read_result
extern fn_print
extern fn_barray_equalp

extern init_macro_stacks
extern free_macro_stacks

;; TODO tmp
extern macro_stack_normal
extern macro_stack_reader
extern macro_stack_new
extern macro_stack_free
extern macro_stack_push
extern macro_stack_pop
extern macro_stack_peek
extern macro_stack_bindump_buffers
extern macro_stack_peek_by_name
extern macro_stack_pop_by_name
extern fn_byte_buffer_delete_bytes
extern barray_new
extern parray_literal

section .rodata

stdin_fd: equ 0
stdout_fd: equ 1
stderr_fd: equ 2

welcome_msg:      db  "Welcome!",10
welcome_msg_len:  equ $ - welcome_msg

buffer_msg: db 10,"Read result backing buffer",10,"--------",10
buffer_msg_len: equ $ - buffer_msg

result_msg: db 10,"Read result",10,"--------",10
result_msg_len: equ $ - result_msg

print_msg: db 10,"Fed back into aarrp printer",10,"--------",10
print_msg_len: equ $ - print_msg

test_macro_name: db 3,0,0,0,0,0,0,0,"foo"
test_macro_code: db 11,0,0,0,0,0,0,0,"code-stuffs"

test_macro_name_2: db 3,0,0,0,0,0,0,0,"bar"
test_macro_code_2: db 11,0,0,0,0,0,0,0,"aaaaaaaaaaa"

test_macro_name_3: db 4,0,0,0,0,0,0,0,"fooo"

section .text

;; TODO: count allocations and warn if not everything has been freed at the end
;; TODO: utility to push all registers and utility to pop all registers,
;;       to make it easy to inject debugging functions in the middle of something
;; TODO: make sure we're handling all errors that could occur from syscalls
;; TODO fn_write_as_base isn't keeping the stack 16-aligned while making function calls
;; TODO: rather than error outright, the reader should generate error codes for things like unexpected EOF for us to handle here
;; TODO: use nasm's local labels (leading .)
;; TODO: remove fn_ function prefixes, see if there are any other namespacing tools available that don't mess with C interop in a weird way.
_start:
  ;; Output welcome string to stderr
  ;;mov rdi, welcome_msg
  ;;mov rsi, welcome_msg_len
  ;;mov rdx, stderr_fd
  ;;call fn_write

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  call init_macro_stacks

  ;;mov rdi, qword[macro_stack_normal]
  ;;mov rsi, test_macro_name
  ;;mov rdx, test_macro_code
  ;;call macro_stack_push

  ;;mov rdi, qword[macro_stack_normal]
  ;;mov rsi, test_macro_name_2
  ;;mov rdx, test_macro_code_2
  ;;call macro_stack_push

  ;;mov rdi, qword[macro_stack_normal]
  ;;mov rsi, test_macro_name
  ;;call macro_stack_pop_by_name

  ;; Newline
  ;;mov rdi, 10
  ;;mov rsi, stdout_fd
  ;;call fn_write_char

  mov rdi, qword[macro_stack_reader]
  mov rsi, stderr_fd
  mov rdx, 16
  call macro_stack_bindump_buffers

  mov rdi, stdin_fd
  call fn_read
  mov r12, rax

  mov rdi, buffer_msg
  mov rsi, buffer_msg_len
  mov rdx, stdout_fd
  call fn_write

  mov rdi, r12
  mov rsi, stdout_fd
  mov rdx, 16
  call fn_dump_read_result_buffer

  mov rdi, result_msg
  mov rsi, result_msg_len
  mov rdx, stdout_fd
  call fn_write

  mov rdi, r12
  mov rsi, stdout_fd
  mov rdx, 16
  call fn_dump_read_result

  mov rdi, print_msg
  mov rsi, print_msg_len
  mov rdx, stdout_fd
  call fn_write


  mov rdi, r12
  mov rsi, stdout_fd
  call fn_print

  mov rdi, r12
  call fn_free_read_result

  ;; Newline
  mov rdi, 10
  mov rsi, stdout_fd
  call fn_write_char

  call free_macro_stacks

  mov rdi, 0
  call fn_exit
