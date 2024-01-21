section .text
global push_builtin_structural_macros

extern byte_buffer_push_barray
extern byte_buffer_push_barray_bytes
extern byte_buffer_push_bytes

extern macro_stack_push_range

extern macro_stack_structural

section .rodata

barray_test_macro_name: db 11,0,0,0,0,0,0,0,"barray-test"
parray_test_macro_name: db 11,0,0,0,0,0,0,0,"parray-test"

barray_literal_macro_name: db 17,0,0,0,0,0,0,0,"test_macro_barray"
barray_test_expansion: db 17,0,0,0,0,0,0,0,"test_macro_barray"

parray_element: db 3,0,0,0,0,0,0,0,"foo"
parray_test_expansion: dq -3,parray_element,parray_element

section .text

;;; push_builtin_structural_macros()
;;;   Pushes builtin structural macros to the structural macro stack
push_builtin_structural_macros:
  sub rsp, 8

  ;; Push barray-test macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, barray_test_macro_name          ; macro name
  mov rdx, barray_test                     ; code
  mov rcx, (barray_test_end - barray_test) ; length
  call macro_stack_push_range

  ;; Push parray-test macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, parray_test_macro_name          ; macro name
  mov rdx, parray_test                     ; code
  mov rcx, (parray_test_end - parray_test) ; length
  call macro_stack_push_range

  add rsp, 8
  ret

;;; barray_test(*structure, *output_byte_buffer)
;;;   Test macro that produces a static barray
barray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, barray_test_expansion
  call byte_buffer_push_barray

  add rsp, 8
  pop r13
  pop r12
  ret
barray_test_end:

;;; parray_test(*structure, *output_byte_buffer)
;;;   Test macro that produces a static parray
parray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, parray_test_expansion
  mov rdx, (8 * 3)
  call byte_buffer_push_bytes

  add rsp, 8
  pop r13
  pop r12
  ret
parray_test_end:
