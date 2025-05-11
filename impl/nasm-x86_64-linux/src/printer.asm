section .text
global print
extern assert_stack_aligned
extern write_char
extern write
extern macro_stack_printer
extern kv_stack_call_by_key

section .rodata
data_macro_name: db 4,0,0,0,0,0,0,0,"data"

section .text

;; print(*data, fd)
print:
  sub rsp, 8

  cmp rdi, 0 ; Don't do anything if data is NULL
  je .done

  ;; Call top-level 'data' macro
  mov rdx, rdi ; *data
  mov rcx, rsi ; fd
  mov rdi, qword[macro_stack_printer]
  mov rsi, data_macro_name
  call kv_stack_call_by_key

  .done:
  add rsp, 8
  ret
