;;;; Macro stack bindings
;;;;   Creates macro stacks for structural, reader, printer macros.

section .text
global init_macro_stacks
global free_macro_stacks

global macro_stack_structural
global macro_stack_reader
global macro_stack_printer

extern macro_stack_new
extern macro_stack_free
extern assert_stack_aligned
extern push_builtin_reader_macros
extern push_builtin_printer_macros
extern push_builtin_structural_macros

section .bss

macro_stack_structural: resq 1
macro_stack_reader: resq 1
macro_stack_printer: resq 1

section .text

;;; init_macro_stacks()
;;;   Initializes macro stacks. Do this before using any of the below bindings.
;;;
;;;   Free macro stacks with free_macro_stacks when done.
init_macro_stacks:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Create stacks
  call macro_stack_new
  mov qword[macro_stack_structural], rax
  call macro_stack_new
  mov qword[macro_stack_reader], rax
  call macro_stack_new
  mov qword[macro_stack_printer], rax

  ;; Push builtin macros
  call push_builtin_reader_macros
  call push_builtin_printer_macros
  call push_builtin_structural_macros

  add rsp, 8
  ret

;;; free_macro_stacks()
;;;   Frees macro stacks.
free_macro_stacks:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rdi, qword[macro_stack_structural]
  call macro_stack_free
  mov rdi, qword[macro_stack_reader]
  call macro_stack_free
  mov rdi, qword[macro_stack_printer]
  call macro_stack_free

  add rsp, 8
  ret
