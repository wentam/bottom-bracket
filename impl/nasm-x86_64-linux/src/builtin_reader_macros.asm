;; TODO should buffered_fd_reader and the output byte_buffer actually
;; be the public interface for this? Neither was built with being
;; a public interface in mind.
;;
;; TODO right now the rule is that reader macros must output buffer-relative
;; pointers due to the need for the output buffer to resize (both for return
;; value and when referencing anything else.
;;
;; Do we want this to be the normal requirement for user-defined reader macros?
;;
;; Requiring reader macros to do their own allocation could be one solution
;; - but also perhaps slower. Also harder to 'free'.
;;
;; TODO multi-char reader macros? should be able to dispatch on "foo"
;;
;; TODO Currently we call '_read' not 'read' as we need the 'recursive implementation'
;; Is it possible to do this nicer? Better interface for "this is the recursive version"?
;;
;; I believe CL has you distinguish the difference by passing a 'recursive' flag
;; to the read function.
;;
;; TODO instead of needing to push a barray for code, builtins would be cleaner
;; if the macro_stack allowed you to simply specify a pointer to already valid
;; memory (and maybe a length if it needs that).

section .text
global push_builtin_reader_macros

extern macro_stack_reader
extern macro_stack_push

extern BUFFERED_READER_EOF
extern fn_error_exit
extern fn__read
extern fn_buffered_fd_reader_read_byte
extern fn_byte_buffer_push_int64
extern fn_byte_buffer_get_data_length
extern fn_buffered_fd_reader_consume_leading_whitespace
extern fn_assert_stack_aligned
extern barray_new
extern fn_free
extern fn_bindump

extern fn_write_char
extern fn_write_as_base

;; TODO tmp
global parray_literal

section .rodata

parray_literal_macro_name: db 1,0,0,0,0,0,0,0,"("

unexpected_eof_parray_str: db "ERROR: Unexpected EOF while reading parray (are your parenthesis mismatched?)",10
unexpected_eof_parray_str_len: equ $ - unexpected_eof_parray_str

section .text

;;; push_builtin_reader_macros()
;;;   Pushes builtin reader macros to the reader macro stack
push_builtin_reader_macros:
  push r12

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; push parray literal macro
  mov rdi, (parray_literal_end - parray_literal)
  mov rsi, parray_literal
  call barray_new
  mov r12, rax

  mov rdi, qword[macro_stack_reader] ; macro stack
  mov rsi, parray_literal_macro_name ; macro name
  mov rdx, r12                       ; code barray
  call macro_stack_push

  mov rdi, r12
  call fn_free

  pop r12
  ret

;;; parray_literal(*buffered_fd_reader, *output_byte_buffer) -> buf-relative-ptr
;;;   Reader macro for parrays using '(' and ')'
parray_literal:
  push r12
  push r14
  push r15
  push rbx
  push rbp
  mov rbp, rsp

  %ifdef ASSERT_STACK_ALIGNMENT
  mov rax, fn_assert_stack_aligned
  call rax
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume the leading '(' TODO assert that it is actually '('
  mov rdi, r12
  mov rax, fn_buffered_fd_reader_read_byte
  call rax

  mov r15, 0 ; child counter
  .children:
  ;; Consume all whitespace
  mov rdi, r12
  mov rax, fn_buffered_fd_reader_consume_leading_whitespace
  call rax

  ;; Peek the next char (consume whitespace also peeks). If it's ')' we're done.
  cmp rax, ')'
  je .done

  ;; Error if it's EOF here
  cmp rax, BUFFERED_READER_EOF
  jne .no_eof

  mov rdi, unexpected_eof_parray_str
  mov rsi, unexpected_eof_parray_str_len
  mov rax, fn_error_exit
  call rax

  .no_eof:

  ;; Read a child
  mov rdi, r12
  mov rsi, r14
  mov rax, fn__read
  call rax

  ;; Push a (relative) pointer to this child onto the stack
  sub rsp, 8
  push rax

  inc r15 ; increment child counter

  jmp .children ; Next child

  .done:


  ;; Consume the trailing ')'
  mov rdi, r12
  mov rax, fn_buffered_fd_reader_read_byte
  call rax

  ;; Zero rbx to start tracking parray size in bytes
  xor rbx, rbx

  ;; Write the parray length
  mov rdi, r14
  mov rsi, r15
  neg rsi ; Negate rsi as parrays should use -length
  mov rax, fn_byte_buffer_push_int64
  call rax

  add rbx, 8 ; 8 bytes for parray length

  ;; Output parray pointers
  .output_parray:
  cmp r15, 0
  je .output_parray_break

  mov rdi, r15
  imul rdi, 16
  sub rdi, 16

  mov rcx, rsp
  add rcx, rdi

  mov rsi, qword[rcx]

  mov rdi, r14
  mov rax, fn_byte_buffer_push_int64
  call rax

  add rbx, 8 ; 8 bytes for pointer

  dec r15
  jmp .output_parray

  .output_parray_break:

  mov rsp, rbp

  ;; Set rax to a relative pointer to the start of the parray
  mov rdi, r14
  mov rax, fn_byte_buffer_get_data_length
  call rax
  sub rax, rbx

  pop rbp
  pop rbx
  pop r15
  pop r14
  pop r12
  ret
parray_literal_end: ;; Needed to calculate length for macro stack
