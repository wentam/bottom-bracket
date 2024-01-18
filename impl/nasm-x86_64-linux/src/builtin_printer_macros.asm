;; TODO: instead of printer macros directly outputting to
;; an fd, they should probably output to a buffered output
;; class (that probably happens to output to an fd).
;;
;; lots of tiny fd writes are innefficient, and the output always
;; being an fd isn't neccessarily something we want to lock ourselves
;; into
;;
;; TODO right now the standard macro stacks are called 'macro_stack_x',
;; which is also how macro_stack methods are named. This is a little
;; confusing and should probably be changed.

section .text
global push_builtin_printer_macros

extern print
extern barray_new
extern assert_stack_aligned
extern macro_stack_printer
extern macro_stack_push
extern macro_stack_call_by_name
extern free
extern write_char
extern write

section .rodata
parray_macro_name: db 6,0,0,0,0,0,0,0,"parray"
barray_macro_name: db 6,0,0,0,0,0,0,0,"barray"
data_macro_name: db 4,0,0,0,0,0,0,0,"data"

section .text

push_builtin_printer_macros:
  push r12

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; push top-level 'data' macro
  mov rdi, (data_end - data)
  mov rsi, data
  call barray_new
  mov r12, rax ; data with our data macro code in it

  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, data_macro_name          ; macro name
  mov rdx, r12                        ; code
  call macro_stack_push

  mov rdi, r12
  call free

  ;; push barray macro
  mov rdi, (barray_end - barray)
  mov rsi, barray
  call barray_new
  mov r12, rax ; barray with our barray macro code in it

  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, barray_macro_name          ; macro name
  mov rdx, r12                        ; code
  call macro_stack_push

  mov rdi, r12
  call free

  ;; push parray macro
  mov rdi, (parray_end - parray)
  mov rsi, parray
  call barray_new
  mov r12, rax ; barray with our parray macro code in it

  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, parray_macro_name          ; macro name
  mov rdx, r12                        ; code
  call macro_stack_push

  mov rdi, r12
  call free

  pop r12
  ret

;; data(*data, fd)
data:
  push r12
  push r13
  push r15
  mov r12, rdi ; aarrp expression data
  mov r13, rsi ; fd

  %ifdef ASSERT_STACK_ALIGNMENT
  mov rax, assert_stack_aligned
  call rax
  %endif

  ;; Decide if this is parray or barray
  mov r15, qword[r12] ; r15 = length of parray/barray
  cmp r15, 0
  jge .barray

  ;; Call parray macro
  mov rdi, qword[macro_stack_printer]
  mov rsi, parray_macro_name
  mov rdx, r12
  mov rcx, r13
  mov rax, macro_stack_call_by_name
  call rax
  jmp .epilogue

  .barray:
  ;; Call barray macro
  mov rdi, qword[macro_stack_printer]
  mov rsi, barray_macro_name
  mov rdx, r12
  mov rcx, r13
  mov rax, macro_stack_call_by_name
  call rax

  .epilogue:
  pop r15
  pop r13
  pop r12
  ret
data_end:

;; barray(*data, fd)
barray:
  push r12
  mov r12, rdi ; *data

  mov rcx, qword[r12] ; Length of barray
  add r12, 8          ; Move past length

  mov rdx, rsi ; fd
  mov rdi, r12
  mov rsi, rcx
  mov rax, write
  call rax

  pop r12
  ret
barray_end:

;; parray(*data, fd)
parray:
  push r12
  push r13
  push r15
  mov r12, rdi ; *data
  mov r13, rsi ; fd

  mov r15, qword[r12] ; Length of parray as one's complement
  not r15             ; Make length positive
  add r12, 8          ; Move past parray length in data

  ;; Write leading '('
  mov rdi, '('
  mov rsi, r13
  mov rax, write_char
  call rax

  .print_child:
    cmp r15, 0
    je .print_child_break

    ;; Print this child
    mov rdi, qword[r12]
    mov rsi, r13
    mov rax, print
    call rax

    cmp r15, 1
    je .nospace

    mov rdi, ' '
    mov rsi, r13
    mov rax, write_char
    call rax

    .nospace:

    add r12, 8
    dec r15
    jmp .print_child

  .print_child_break:

  ;; Write trailing ')'
  mov rdi, ')'
  mov rsi, r13
  mov rax, write_char
  call rax

  pop r15
  pop r13
  pop r12
  ret

parray_end:
