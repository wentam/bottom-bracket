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
;; if the kv_stack allowed you to simply specify a pointer to already valid
;; memory (and maybe a length if it needs that).
;;
;; TODO barrays that contain a semicolon include the comment
;; TODO comments at the start of our input become the only that evaluated


section .text
global push_builtin_reader_macros
global barray_invalid_chars

extern macro_stack_reader
extern kv_stack_push

extern BUFFERED_READER_EOF
extern error_exit
extern _read
extern buffered_fd_reader_read_byte
extern byte_buffer_push_int64
extern byte_buffer_get_data_length
extern buffered_fd_reader_consume_leading_whitespace
extern assert_stack_aligned
extern barray_new
extern free
extern bindump
extern buffered_fd_reader_peek_byte
extern byte_buffer_push_byte
extern byte_buffer_write_int64
extern byte_buffer_get_buf
extern parse_uint
extern alpha36p
extern alpha10p
extern byte_in_barray_p

extern write_char
extern write_as_base

section .rodata

parray_literal_macro_name: db 1,0,0,0,0,0,0,0,"["
byte_string_macro_name: db 1,0,0,0,0,0,0,0,'"'
comment_literal_macro_name: db 1,0,0,0,0,0,0,0,";"

;; TODO once we have multi-char reader macros
;; this may cause name conflicts
barray_literal_macro_name: db 8,0,0,0,0,0,0,0,"catchall"

unexpected_eof_parray_str: db "ERROR: Unexpected EOF while reading parray (are your brackets mismatched?)",10
unexpected_eof_parray_str_len: equ $ - unexpected_eof_parray_str

unexpected_eof_bstring_str: db "ERROR: Unexpected EOF while reading byte string (are your double quotes mismatched?)",10
unexpected_eof_bstring_str_len: equ $ - unexpected_eof_bstring_str

unexpected_eof_barray_str: db "ERROR: Unexpected EOF while reading barray",10
unexpected_eof_barray_str_len: equ $ - unexpected_eof_barray_str

unexpected_paren_str: db "ERROR: Unexpected ')' while reading",10
unexpected_paren_str_len: equ $ - unexpected_paren_str

invalid_hex_str: db "ERROR: Invalid hex literal while reading byte string (must be 2x A-Z a-z 0-9)",10
invalid_hex_str_len: equ $ - invalid_hex_str

invalid_dec_str: db "ERROR: Invalid dec literal while reading byte string (must be 3x 0-9) and <256",10
invalid_dec_str_len: equ $ - invalid_dec_str

%define NEWLINE 10
%define TAB 9

barray_invalid_chars: db 6,0,0,0,0,0,0,0,'[',']',' ','"',NEWLINE,TAB

section .text

;;; push_builtin_reader_macros()
;;;   Pushes builtin reader macros to the reader macro stack
push_builtin_reader_macros:
  sub rsp, 8

  ;; push barray literal macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], barray_literal
  mov rdi, qword[macro_stack_reader] ; macro stack
  mov rsi, barray_literal_macro_name ; macro name
  mov rdx, rsp                       ; code
  call kv_stack_push
  add rsp, 16

  ;; push comment literal macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], comment_literal
  mov rdi, qword[macro_stack_reader] ; macro stack
  mov rsi, comment_literal_macro_name ; macro name
  mov rdx, rsp                        ; code
  call kv_stack_push
  add rsp, 16

  ;; push parray literal macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], parray_literal
  mov rdi, qword[macro_stack_reader] ; macro stack
  mov rsi, parray_literal_macro_name ; macro name
  mov rdx, rsp            ; code
  call kv_stack_push
  add rsp, 16

  ;; push byte_string literal macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], byte_string
  mov rdi, qword[macro_stack_reader]       ; macro stack
  mov rsi, byte_string_macro_name          ; macro name
  mov rdx, rsp                            ; code
  call kv_stack_push
  add rsp, 16

  add rsp, 8
  ret

;;; byte_string(*buffered_fd_reader, *output_byte_buffer) -> buf-relative-ptr
byte_string:
  push r12
  push r13
  push r15
  mov r12, rdi ; buffered fd reader
  mov r13, rsi ; output byte buffer

  ;; Write length placeholder
  mov rdi, r13
  mov rsi, 0
  mov rax, byte_buffer_push_int64
  call rax

  ;; Consume the leading '"'
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax

  mov r15, 0 ; byte counter
  .byte:
    ;; Peek the next byte
    mov rdi, r12
    mov rax, buffered_fd_reader_peek_byte
    call rax

    ;; If it's our ending ", leave
    cmp rax, '"'
    je .byte_break

    ;; Actually consume the byte
    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax

    ;; --------------------
    ;; --- Escape codes ---

    cmp rax, '\'
    jne .not_escape

    ;; It's an escape char. Consume the next byte to determine escape type
    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax

    cmp rax, BUFFERED_READER_EOF
    je .eof

    cmp rax, 'n'
    jne .not_newline

    ;; It's a newline escape code, output literal newline
    mov rdi, r13
    mov rsi, 10
    mov rax, byte_buffer_push_byte
    call rax
    jmp .next

    .not_newline:

    cmp rax, '\'
    jne .not_backslash

    ;; It's a backslash escape, output '\'
    mov rdi, r13
    mov rsi, '\'
    mov rax, byte_buffer_push_byte
    call rax
    jmp .next

    .not_backslash:

    cmp rax, '"'
    jne .not_dquote

    ;; It's a double quote escape, output '"'
    mov rdi, r13
    mov rsi, '"'
    mov rax, byte_buffer_push_byte
    call rax
    jmp .next

    .not_dquote:

    cmp rax, 'x'
    jne .not_hex_literal

    ;; It's a hex literal

    ;; Make room to put the hex literal on the stack
    sub rsp, 2

    ;; It's a hex literal. Read the next two bytes onto the stack.
    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax
    mov byte[rsp], al

    ;; Error if not A-Z a-z 0-9
    mov rdi, rax
    mov rax, alpha36p
    call rax
    cmp rax, 1
    je .good_hex_char_1

    mov rdi, invalid_hex_str
    mov rsi, invalid_hex_str_len
    mov rax, error_exit
    call rax

    .good_hex_char_1:

    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax
    mov byte[rsp+1], al

    ;; Error if not A-Z a-z 0-9
    mov rdi, rax
    mov rax, alpha36p
    call rax
    cmp rax, 1
    je .good_hex_char_2

    mov rdi, invalid_hex_str
    mov rsi, invalid_hex_str_len
    mov rax, error_exit
    call rax

    .good_hex_char_2:

    push 2 ; length of barray

    ;; Parse hex literal
    mov rdi, rsp ; barray
    mov rsi, 16  ; base
    mov rax, parse_uint
    call rax

    ;; Re-align stack
    add rsp, 10

    ;; Push the parsed hex literal
    mov rdi, r13
    mov rsi, rax
    mov rax, byte_buffer_push_byte
    call rax
    jmp .next

    .not_hex_literal:

    cmp rax, 'd'
    jne .not_dec_literal

    ;; It's a dec literal

    ;; Make room to put the hex literal on the stack
    sub rsp, 3

    ;; It's a dec literal. Read the next three bytes onto the stack.
    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax
    mov byte[rsp], al

    ;; Error if not 0-9
    mov rdi, rax
    mov rax, alpha10p
    call rax
    cmp rax, 1
    je .good_dec_char_1

    mov rdi, invalid_dec_str
    mov rsi, invalid_dec_str_len
    mov rax, error_exit
    call rax

    .good_dec_char_1:

    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax
    mov byte[rsp+1], al

    ;; Error if not 0-9
    mov rdi, rax
    mov rax, alpha10p
    call rax
    cmp rax, 1
    je .good_dec_char_2

    mov rdi, invalid_dec_str
    mov rsi, invalid_dec_str_len
    mov rax, error_exit
    call rax

    .good_dec_char_2:

    mov rdi, r12
    mov rax, buffered_fd_reader_read_byte
    call rax
    mov byte[rsp+2], al

    ;; Error if not 0-9
    mov rdi, rax
    mov rax, alpha10p
    call rax
    cmp rax, 1
    je .good_dec_char_3

    mov rdi, invalid_dec_str
    mov rsi, invalid_dec_str_len
    mov rax, error_exit
    call rax

    .good_dec_char_3:

    push 3 ; length of barray

    ;; Parse hex literal
    mov rdi, rsp ; barray
    mov rsi, 10  ; base
    mov rax, parse_uint
    call rax

    ;; Re-align stack
    add rsp, 11

    ;; Error if dec literal > 255
    cmp rax, 256
    jl .dec_in_range

    mov rdi, invalid_dec_str
    mov rsi, invalid_dec_str_len
    mov rax, error_exit
    call rax

    .dec_in_range:

    ;; Push the parsed dec literal
    mov rdi, r13
    mov rsi, rax
    mov rax, byte_buffer_push_byte
    call rax
    jmp .next

    .not_dec_literal:

    ;; TODO binary literals \b10101010
    ;; TODO terminal bell \a (ASCII code 0x07)
    ;; TODO backspace \b     (ASCII code 0x08)
    ;; TODO page break \f    (ASCII code 0x0C)
    ;; TODO tab \t           (ASCII code 0x09)
    ;; TODO vertical tab \v  (ASCII code 0x0B)
    ;; TODO multiline strings

    .not_escape:

    ;; --- End escape codes ---
    ;; ------------------------

    ;; Error if it's EOF here
    cmp rax, BUFFERED_READER_EOF
    jne .no_eof

    .eof:
    mov rdi, unexpected_eof_bstring_str
    mov rsi, unexpected_eof_bstring_str_len
    mov rax, error_exit
    call rax

    .no_eof:

    ;; Push the byte to output
    mov rdi, r13
    mov rsi, rax
    mov rax, byte_buffer_push_byte
    call rax

    .next:

    inc r15
    jmp .byte

  .byte_break:

  ;; Consume the trailing '"'
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax

  ;; Set rax to a relative pointer to the start of the barray
  mov rdi, r13
  mov rax, byte_buffer_get_data_length
  call rax
  sub rax, r15
  sub rax, 8

  ;; Update the length placeholder to real length
  push rax
  sub rsp, 8
  mov rdi, r13
  mov rsi, rax
  mov rdx, r15
  mov rax, byte_buffer_write_int64
  call rax
  add rsp, 8
  pop rax

  pop r15
  pop r13
  pop r12
  ret
byte_string_end:

;;; parray_literal(*buffered_fd_reader, *output_byte_buffer) -> buf-relative-ptr
;;;   Reader macro for parrays using '[' and ']'
parray_literal:
  push r12
  push r14
  push r15
  push rbx
  push rbp
  mov rbp, rsp

  %ifdef ASSERT_STACK_ALIGNMENT
  mov rax, assert_stack_aligned
  call rax
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume the leading '[' TODO assert that it is actually '['?
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax

  mov r15, 0 ; child counter
  .children:
  ;; Consume all whitespace
  mov rdi, r12
  mov rax, buffered_fd_reader_consume_leading_whitespace
  call rax

  ;; Peek the next char (consume whitespace also peeks). If it's ']' we're done.
  cmp rax, ']'
  je .done

  ;; Error if it's EOF here
  cmp rax, BUFFERED_READER_EOF
  jne .no_eof

  mov rdi, unexpected_eof_parray_str
  mov rsi, unexpected_eof_parray_str_len
  mov rax, error_exit
  call rax

  .no_eof:

  ;; Read a child
  mov rdi, r12
  mov rsi, r14
  mov rax, _read
  call rax

  cmp rax, -1
  je .empty_child

  ;; Push a (relative) pointer to this child onto the stack
  sub rsp, 8
  push rax

  inc r15 ; increment child counter

  .empty_child:

  jmp .children ; Next child

  .done:

  ;; Consume the trailing ']'
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax

  ;; Zero rbx to start tracking parray size in bytes
  xor rbx, rbx

  ;; Write the parray length
  mov rdi, r14
  mov rsi, r15
  not rsi ; Negate rsi as parrays should use one's complement -length
  mov rax, byte_buffer_push_int64
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
  mov rax, byte_buffer_push_int64
  call rax

  add rbx, 8 ; 8 bytes for pointer

  dec r15
  jmp .output_parray

  .output_parray_break:

  mov rsp, rbp

  ;; Set rax to a relative pointer to the start of the parray
  mov rdi, r14
  mov rax, byte_buffer_get_data_length
  call rax
  sub rax, rbx

  pop rbp
  pop rbx
  pop r15
  pop r14
  pop r12
  ret
parray_literal_end: ;; Needed to calculate length for macro stack

;;; barray_literal(*buffered_fd_reader, *output_byte_buffer) -> buf-relative-ptr
;;;   Reader macro for barray literals.
barray_literal:
  push r12
  push r14
  push r15
  push rbx
  push r13

  %ifdef ASSERT_STACK_ALIGNMENT
  mov rax, assert_stack_aligned
  call rax
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume all the leading whitespace
  mov rdi, r12
  mov rax, buffered_fd_reader_consume_leading_whitespace
  call rax

  cmp rax, ']'
  jne .no_closeparen

  mov rdi, unexpected_paren_str
  mov rsi, unexpected_paren_str_len
  mov rax, error_exit
  call rax

  .no_closeparen:

  cmp rax, BUFFERED_READER_EOF
  jne .no_eof

  mov rdi, unexpected_eof_barray_str
  mov rsi, unexpected_eof_barray_str_len
  mov rax, error_exit
  call rax

  .no_eof:

  ;; Write length placeholder
  mov rdi, r14
  mov rsi, 0
  mov rax, byte_buffer_push_int64
  call rax

  ;; Read characters until the end of the barray
  mov rbx, 0 ;; char counter
  .char:
  ;; Peek the next char - if it's '[', ']' or whitespace, we're done.
  ;; We cannot consume because consuming '[' or ']' would be damaging.
  mov rdi, r12 ; buffered reader
  mov rax, buffered_fd_reader_peek_byte
  call rax
  cmp rax, BUFFERED_READER_EOF
  je .finish
  mov rdi, rax
  mov rsi, barray_invalid_chars
  mov rax, byte_in_barray_p
  call rax
  cmp rax, 1
  je .finish

  ;; Read the next char
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax
  mov r15, rax

  ;; Output this char to the buffer
  mov rdi, r14
  mov rsi, r15
  mov rax, byte_buffer_push_byte
  call rax

  inc rbx

  ;; Repeat
  jmp .char

  .finish:
  ;; Update barray length placeholder

  mov rdi, r14
  mov rax, byte_buffer_get_data_length ; Get data length
  call rax
  mov r12, rax

  mov rdi, r14
  mov rax, byte_buffer_get_buf         ; Get data
  call rax
  mov r13, rax
  add rax, r12                        ; Buffer pointer forward to write pos

  sub rax, rbx                      ; Subtract whatever we just wrote
  sub rax, 8                        ; Subtract our placeholder length
  mov qword[rax], rbx               ; Write our length

  sub rax, r13 ; We want to return a relative pointer

  pop r13
  pop rbx
  pop r15
  pop r14
  pop r12
  ret
barray_literal_end:

;;; comment_literal(*buffered_fd_reader, *output_byte_buffer) -> buf-relative-ptr
;;;   Reader macro for comments
comment_literal:
  push r12
  push r14
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  mov rax, assert_stack_aligned
  call rax
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume chars until we hit a newline (don't consume the newline)

  .char:
  ;; peek next
  mov rdi, r12 ; buffered reader
  mov rax, buffered_fd_reader_peek_byte
  call rax
  cmp rax, 0x0A ; newline
  je .epilogue
  cmp rax, BUFFERED_READER_EOF
  je .epilogue

  ;; consume the byte
  mov rdi, r12
  mov rax, buffered_fd_reader_read_byte
  call rax

  jmp .char

  .epilogue:
  mov rax, -1
  add rsp, 8
  pop r14
  pop r12
  ret
comment_literal_end:
