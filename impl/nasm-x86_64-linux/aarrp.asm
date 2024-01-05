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
extern fn_print
extern fn_exit
extern fn_write_char
extern fn_read_char
extern fn_malloc
extern fn_write_as_base
extern fn_free

section .rodata

stdin_fd: equ 0
stdout_fd: equ 1
stderr_fd: equ 2

welcome_msg:      db  "Welcome!",10
welcome_msg_len:  equ $ - welcome_msg

section .text

_start:
  ;; Output welcome string to stderr
  mov rdi, welcome_msg
  mov rsi, welcome_msg_len
  mov rdx, stderr_fd
  call fn_print

  ;; Test malloc
  mov rdi, 4096
  call fn_malloc

  mov r12, rax
  mov qword [r12], 0

  mov rdi, rax
  call fn_free

  ;;mov rdi, rax
  ;;mov rsi, 16
  ;;mov rdx, stdout_fd
  ;;call fn_write_as_base

  ;;mov qword [r12], 10

 ;; Print pointer given to us by malloc
 ;; mov rdi, rax
 ;; mov rsi, stdout_fd
 ;; call fn_write_char

  mov rdi, 0
  call fn_exit
