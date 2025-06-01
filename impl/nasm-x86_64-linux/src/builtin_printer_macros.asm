;; TODO: instead of printer macros directly outputting to
;; an fd, they should probably output to a buffered output
;; class - perhaps byte buffer.
;;
;; lots of tiny fd writes are innefficient, and the output always
;; being an fd isn't neccessarily something we want to lock ourselves
;; into

section .text
global push_builtin_printer_macros

extern kv_stack_value_by_key
extern print
extern barray_new
extern assert_stack_aligned
extern macro_stack_printer
extern kv_stack_push
extern free
extern write_char
extern write
extern visible_char_p
extern barray_invalid_chars
extern byte_in_barray_p
extern write_as_base

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
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], data
  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, data_macro_name            ; macro name
  mov rdx, rsp                        ; code
  call kv_stack_push
  add rsp, 16

  ;; push barray macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], barray
  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, barray_macro_name          ; macro name
  mov rdx, rsp                        ; code
  call kv_stack_push
  add rsp, 16

  ;; push barray with byte-strings macro
  ;; we intentionally shadow the other barray macro such
  ;; that you can easily pop this one off the stack to get all barrays
  ;; printed literally

  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], barray_with_byte_strings
  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, barray_macro_name          ; macro name
  mov rdx, rsp ; code
  call kv_stack_push
  add rsp, 16

  ;; push parray macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], parray
  mov rdi, qword[macro_stack_printer] ; macro stack
  mov rsi, parray_macro_name          ; macro name
  mov rdx, rsp ; code
  call kv_stack_push
  add rsp, 16

  pop r12
  ret

;;; data(*data, fd)
data:
  push r12
  push r13
  push r15
  mov r12, rdi ; expression data
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
  mov rax, kv_stack_value_by_key
  call rax
  mov rdi, r12
  mov rsi, r13
  call qword[rax+8]
  jmp .epilogue

  .barray:
  ;; Call barray macro
  mov rdi, qword[macro_stack_printer]
  mov rsi, barray_macro_name
  mov rax, kv_stack_value_by_key
  call rax
  mov rdi, r12
  mov rsi, r13
  call qword[rax+8]

  .epilogue:
  pop r15
  pop r13
  pop r12
  ret
data_end:

;;; barray(*data, fd)
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

;;; barray_with_byte_strings(*data, fd)
barray_with_byte_strings:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8
  mov r12, rdi ; *data
  mov r13, rsi ; fd

  ;; Check if we need to use a byte string for this string
  mov r15, qword[r12] ; Length of barray
  mov r14, r12
  add r14, 8 ; Move past length
  .check_loop:
    cmp r15, 0
    je .check_loop_break

    ;; If this isn't a visible ascii char -> byte string
    xor rdi, rdi
    mov dil, byte[r14]
    mov rax, visible_char_p
    call rax
    cmp rax, 0
    je .as_byte_string

    ;; If this contains a barray invalid char -> byte string
    xor rdi, rdi
    mov dil, byte[r14]
    mov rsi, barray_invalid_chars
    mov rax, byte_in_barray_p
    call rax
    cmp rax, 1
    je .as_byte_string

    inc r14
    dec r15
    jmp .check_loop

  .check_loop_break:

  .as_barray_literal:
  mov r15, qword[r12] ; Length of barray
  add r12, 8          ; Move past length

  mov rdx, r13 ; fd
  mov rdi, r12
  mov rsi, r15
  mov rax, write
  call rax
  jmp .epilogue

  .as_byte_string:

  ;; Leading '"'
  mov rdi, '"'
  mov rsi, r13
  mov rax, write_char
  call rax

  mov r15, qword[r12] ; Length of barray
  add r12, 8          ; Move past length
  .as_byte_string_loop:
    cmp r15, 0
    je .as_byte_string_loop_break

    ;; --------------------
    ;; --- Escape codes ---

    ;; Newline
    cmp byte[r12], 10
    jne .not_newline
    mov rdi, '\'
    mov rsi, r13
    mov rax, write_char
    call rax
    mov rdi, 'n'
    mov rsi, r13
    mov rax, write_char
    call rax
    jmp .next
    .not_newline:

    ;; Backslash
    cmp byte[r12], '\'
    jne .not_backslash
    mov rdi, '\'
    mov rsi, r13
    mov rax, write_char
    call rax
    mov rdi, '\'
    mov rsi, r13
    mov rax, write_char
    call rax
    jmp .next
    .not_backslash:

    ;; Double quote
    cmp byte[r12], '"'
    jne .not_dquote
    mov rdi, '\'
    mov rsi, r13
    mov rax, write_char
    call rax
    mov rdi, '"'
    mov rsi, r13
    mov rax, write_char
    call rax
    jmp .next
    .not_dquote:

    ;; Skip hex in the case of space
    cmp byte[r12], ' '
    je .not_hex

    ;; If otherwise not visible, hex literal
    xor rdi, rdi
    mov dil, byte[r12]
    mov rax, visible_char_p
    call rax
    cmp rax, 1
    je .not_hex
    mov rdi, '\'
    mov rsi, r13
    mov rax, write_char
    call rax
    mov rdi, 'x'
    mov rsi, r13
    mov rax, write_char
    call rax
    xor rdi, rdi
    mov dil, byte[r12]
    mov rsi, 16
    mov rdx, r13
    mov rcx, 2
    mov rax, write_as_base
    call rax
    jmp .next
    .not_hex:

    ;; --- End escape codes ---
    ;; --------------------

    xor rdi, rdi
    mov dil, byte[r12]
    mov rsi, r13
    mov rax, write_char
    call rax

    .next:
    inc r12
    dec r15
    jmp .as_byte_string_loop
    .as_byte_string_loop_break:

  ;; Trailing '"'
  mov rdi, '"'
  mov rsi, r13
  mov rax, write_char
  call rax

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret
barray_with_byte_strings_end:

;;; parray(*data, fd)
parray:
  push r12
  push r13
  push r15
  mov r12, rdi ; *data
  mov r13, rsi ; fd

  mov r15, qword[r12] ; Length of parray as one's complement
  not r15             ; Make length positive
  add r12, 8          ; Move past parray length in data

  ;; Write leading '['
  mov rdi, '['
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

  ;; Write trailing ']'
  mov rdi, ']'
  mov rsi, r13
  mov rax, write_char
  call rax

  pop r15
  pop r13
  pop r12
  ret

parray_end:
