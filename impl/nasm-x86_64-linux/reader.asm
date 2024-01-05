section .text
global fn_read
extern fn_read_char

section .rodata
;;; Syscall numbers
sys_write: equ 0x01
sys_read:  equ 0x00
sys_exit:  equ 0x3c

section .text

;;; read(fd)
;;;   Reads one expression from the file descriptor into internal representation
fn_read:
  ;; Consume all the whitespace leading up to the first non-whitespace character
  mov rdi, 0 ; stdin
  call fn_read_char
  ret
