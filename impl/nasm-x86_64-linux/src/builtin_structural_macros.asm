section .text
global push_builtin_structural_macros

extern byte_buffer_push_barray
extern byte_buffer_push_barray_bytes
extern byte_buffer_push_bytes
extern byte_buffer_push_int64

extern macro_stack_push_range
extern macro_stack_push
extern macro_stack_pop

extern macro_stack_structural

section .rodata

barray_test_macro_name: db 11,0,0,0,0,0,0,0,"barray-test"
parray_test_macro_name: db 11,0,0,0,0,0,0,0,"parray-test"
nothing_macro_name: db 7,0,0,0,0,0,0,0,"nothing"
push_macro_macro_name: db 10,0,0,0,0,0,0,0,"push-macro"
pop_macro_macro_name: db 9,0,0,0,0,0,0,0,"pop-macro"

barray_literal_macro_name: db 17,0,0,0,0,0,0,0,"test_macro_barray"
barray_test_expansion: db 17,0,0,0,0,0,0,0,"test_macro_barray"

parray_element: db 3,0,0,0,0,0,0,0,"foo"
parray_element_2: db 4,0,0,0,0,0,0,0,"foo2"
parray_element_3: dq -2,barray_test_macro_name
parray_test_expansion: dq -4,parray_element,parray_element_2,parray_element_3

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

  ;; Push nothing macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, nothing_macro_name          ; macro name
  mov rdx, nothing                     ; code
  mov rcx, (nothing_end - nothing) ; length
  call macro_stack_push_range


  ;; Push push_macro macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, push_macro_macro_name          ; macro name
  mov rdx, push_macro                     ; code
  mov rcx, (push_macro_end - push_macro) ; length
  call macro_stack_push_range

  ;; Push pop_macro macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, pop_macro_macro_name          ; macro name
  mov rdx, pop_macro                     ; code
  mov rcx, (pop_macro_end - pop_macro) ; length
  call macro_stack_push_range

  add rsp, 8
  ret

;;; barray_test(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Test macro that produces a static barray
barray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, barray_test_expansion
  mov rax, byte_buffer_push_barray
  call rax

  mov rax, 0
  add rsp, 8
  pop r13
  pop r12
  ret
barray_test_end:

;;; parray_test(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Test macro that produces a static parray
parray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, parray_test_expansion
  mov rdx, (8 * 4)
  mov rax, byte_buffer_push_bytes
  call rax

  mov rax, 0
  add rsp, 8
  pop r13
  pop r12
  ret
parray_test_end:

;;; nothing(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   macro that expands into nothing
nothing:
  mov rax, -1
  ret

nothing_end:

;;; push_macro(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Macro with a side-effect of pushing a new macro onto the structural
;;;   macro stack. Expands to nothing.
push_macro:
  push r12

  mov r12, rdi ; structure
  ;; TODO error if wrong parameter count
  ;; TODO error if parameters aren't barrays

  mov rdi, qword[macro_stack_structural]
  mov rsi, qword[r12+16]
  mov rdx, qword[r12+24]
  mov rax, macro_stack_push
  call rax

  mov rax, -1
  pop r12
  ret
push_macro_end:


;;; pop_macro(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Macro with a side-effect of popping a macro off the structural macro
;;;   stack. Expands to nothing.
pop_macro:
  push r12

  mov r12, rdi ; structure

  ;; TODO if an argument is specified, do pop-by-name

  mov rdi, qword[macro_stack_structural]
  mov rax, macro_stack_pop
  call rax

  mov rax, -1
  pop r12
  ret

pop_macro_end:
