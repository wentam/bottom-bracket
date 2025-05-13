section .text
global print
extern assert_stack_aligned
extern write_char
extern write
extern macro_stack_printer
extern kv_stack_value_by_key

section .rodata
data_macro_name: db 4,0,0,0,0,0,0,0,"data"

section .text

;; print(*data, fd)
print:
  push r12
  push r13
  push r14

  mov r12, rdi
  mov r13, rsi

  cmp rdi, 0 ; Don't do anything if data is NULL
  je .done

  ;; Call top-level 'data' macro
  mov rdi, qword[macro_stack_printer]
  mov rsi, data_macro_name
  call kv_stack_value_by_key
  mov rdi, r12 ; *data
  mov rsi, r13 ; fd
  call qword[rax+8]

  .done:
  pop r14
  pop r13
  pop r12
  ret
