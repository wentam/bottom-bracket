;; Registers:
;;
;; qword (64-bit): rax [rbx] rcx rdx rsp [rbp] rsi rdi r8  r9  r10  r11  [r12]  [r13]  [r14]  [r15]
;; dword (32-bit): eax [ebx] ecx edx esp [ebp] esi edi r8d r9d r10d r11d [r12d] [r13d] [r14d] [r15d]
;;  word (16-bit):  ax  [bx]  cx  dx  sp  [bp]  si  di r8w r9w r10w r11w [r12w] [r13w] [r14w] [r15w]
;;  byte  (8-bit):  al  [bl]  cl  dl spl [bpl] sil dil r8b r9b r10b r11b [r12b] [r13b] [r14b] [r15b]
;; [callee-preserve register]
;;
;; rsp: stack pointer
;;
;; Function arguments: rdi rsi rdx rcx r8 r9
;; Remaining arguments are passed on the stack in reverse order so that they
;; can be popped off the stack in order.
;;
;; callee preserve registers: rbp, rbx, r12, r13, r14, r15
;;
;; return value: rax
;;
;; The only "non-special" registers are r10 r11.

section .text
global _start
extern fn_print
extern fn_exit

section .rodata
stdout_fd: equ 1
stdin_fd: equ 0
welcome_msg:      db  "Welcome!",10
welcome_msg_len:  equ $ - welcome_msg

section .text

_start:
  ;; Output welcome string
  mov rdi, welcome_msg
  mov rsi, welcome_msg_len
  mov rdx, stdout_fd
  call fn_print

  mov rdi, 0
  call fn_exit
