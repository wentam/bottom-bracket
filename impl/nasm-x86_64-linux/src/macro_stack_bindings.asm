;;;; Macro stack bindings
;;;;   Creates macro stacks for normal, reader, printer macros.

section .text
global init_macro_stacks
global free_macro_stacks

global macro_stack_normal
global macro_stack_reader
global macro_stack_printer

extern macro_stack_new
extern macro_stack_free
extern fn_assert_stack_aligned

section .rodata

section .bss

macro_stack_normal: resq 1
macro_stack_reader: resq 1
macro_stack_printer: resq 1

section .text

;;; struct macro_definition {
;;;   size_t  name_length
;;;   char    name[name_length] // flat in struct
;;;   size_t  code_length;
;;;   char    code[code_length] // flat in struct
;;; }

;;; init_macro_stacks()
;;;   Initializes macro stacks. Do this before using any of the below bindings.
;;;
;;;   Free macro stacks with free_macro_stacks when done.
init_macro_stacks:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  call macro_stack_new
  mov qword[macro_stack_normal], rax
  call macro_stack_new
  mov qword[macro_stack_reader], rax
  call macro_stack_new
  mov qword[macro_stack_printer], rax
  add rsp, 8
  ret

;;; free_macro_stacks()
;;;   Frees macro stacks.
free_macro_stacks:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rdi, qword[macro_stack_normal]
  call macro_stack_free
  mov rdi, qword[macro_stack_reader]
  call macro_stack_free
  mov rdi, qword[macro_stack_printer]
  call macro_stack_free

  add rsp, 8
  ret
