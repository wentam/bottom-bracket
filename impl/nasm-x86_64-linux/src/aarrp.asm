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
extern fn_realloc
extern fn_free
extern fn_write_as_base
extern fn_read
extern fn_assert_stack_aligned
extern fn_bindump

section .rodata

stdin_fd: equ 0
stdout_fd: equ 1
stderr_fd: equ 2

welcome_msg:      db  "Welcome!",10
welcome_msg_len:  equ $ - welcome_msg

section .text

;; TODO: count allocations and warn if not everything has been freed at the end
;; TODO: utility to push all registers and utility to pop all registers,
;;       to make it easy to inject debugging functions in the middle of something
;; TODO: we should probably split out the reader's output buffer to be a byte vector
;; TODO: make sure we're handling all errors that could occur from syscalls
;; TODO fn_write_as_base isn't keeping the stack 16-aligned while making function calls
;; TODO: rather than error outright, the reader should generate error codes for things like unexpected EOF for us to handle here
;; TODO: free read result. Reader probably needs to return a pointer to the
;; output buffer after the array/atom so it knows where to free it. Said pointer
;; could also be helpful to implemented a 'dump buffer' function.
;; TODO: rename reader/buffered_reader to something clearer. Just calling it
;; reader confuses the AARRP expression reader with something like the buffered
;; reader (a reader of bytes from an fd).
_start:
  ;; Output welcome string to stderr
  ;;mov rdi, welcome_msg
  ;;mov rsi, welcome_msg_len
  ;;mov rdx, stderr_fd
  ;;call fn_print

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;;mov rdi, 27
  ;;mov rsi, 16
  ;;mov rdx, stdout_fd
  ;;mov rcx, 3
  ;;call fn_write_as_base

  mov rdi, stdin_fd
  call fn_read
  mov r12, rax

  mov rdi, r12
  mov rsi, 256
  mov rdx, stdout_fd
  mov rcx, 2
  call fn_bindump

  ;; Dump read result to STDOUT
  ;; TODO implement dump func for testing?
  mov r14, 256

  mov r13, r12
  dump:
  cmp r14, 0
  je break
  ;; Dump the byte
  ;;mov dil, byte [r13]
  ;;mov rsi, stdout_fd
  ;;call fn_write_char

  inc r13
  dec r14
  jmp dump
  break:

  ;; TODO: free the read result. We'll need to implement a function
  ;; in the reader for this as our return result is not the start of
  ;; the struct

  ;; Newline
  ;;mov rdi, 10
  ;;mov rsi, stdout_fd
  ;;call fn_write_char

  mov rdi, 0
  call fn_exit
