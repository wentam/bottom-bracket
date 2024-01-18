section .text
global print
extern assert_stack_aligned
extern write_char
extern write
extern macro_stack_printer
extern macro_stack_call_by_name

section .rodata
data_macro_name: db 4,0,0,0,0,0,0,0,"data"

section .text

;; print(*data, fd)
print:
  sub rsp, 8

  ;; Call top-level 'data' macro
  mov rdx, rdi ; *data
  mov rcx, rsi ; fd
  mov rdi, qword[macro_stack_printer]
  mov rsi, data_macro_name
  call macro_stack_call_by_name

  add rsp, 8
  ret
