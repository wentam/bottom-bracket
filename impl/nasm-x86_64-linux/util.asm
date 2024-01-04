section .rodata
;; Syscall numbers
sys_write: equ 0x01
sys_read:  equ 0x00
sys_exit:  equ 0x3c

section .text
global fn_print
global fn_exit

;; print(string, len, fd) - Outputs given string to fd
fn_print:
  mov r10, rdx       ; We're about to clobber rdx
  mov rdx, rsi       ; String length
  mov rsi, rdi       ; String
  mov rdi, r10       ; Output fd
  mov rax, sys_write ; syscall number
  syscall
  ret

;; exit(exit_code) - Exits the program with the given exit code
fn_exit:
                    ; rdi is already exit code
  mov rax, sys_exit ; syscall number
  syscall
  ret
