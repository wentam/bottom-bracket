section .text
global structural_macro_expand
global structural_macro_expand_relptr

extern byte_buffer_get_buf
extern byte_buffer_get_data_length
extern byte_buffer_push_barray
extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_push_int64
extern _relative_to_abs

extern macro_stack_structural

extern macro_stack_call_by_name

extern write_as_base
extern write_char

section .rodata

section .text

structural_macro_expand:
  push r12
  push r13
  push r14

  mov r12, rdi ; data
  mov r13, rsi ; output byte buffer

  call structural_macro_expand_relptr
  cmp rax, -1
  jne .not_nothing
  mov rax, 0
  .not_nothing:


  mov r14, rax ; expansion relative ptr

  ; make r14 an absolute pointer
  mov rdi, r13
  call byte_buffer_get_buf
  add rax, r14

  push rax
  sub rsp, 8
  mov rdi, rax
  mov rsi, r13
  call _relative_to_abs
  add rsp, 8
  pop rax

  .done:
  pop r14
  pop r13
  pop r12
  ret

;;; structural_macro_expand_relptr(*data, *output_byte_buffer) -> ptr
;;;   Produces a recursively (structural) macroexpanded version of *data in
;;;   *output_byte_buffer.
;;;
;;;   Uses buffer-relative pointers, thus not yet a valid AARRP structure.
;;;
;;;   Returns a pointer to the top-level element in *output_byte_buffer
structural_macro_expand_relptr:
  push r12
  push r13
  push r14
  push r15
  push rbx
  push rbp
  sub rsp, 8

  mov r12, rdi ; data
  mov r13, rsi ; output byte buffer

  mov rdi, qword[r12] ; length of first thing in data
  cmp rdi, 0
  jl .expand_parray

  .expand_barray:
  ;; Save our data length to use as our buffer-relative pointer
  mov rdi, r13
  call byte_buffer_get_data_length
  mov r14, rax

  ;; Push this barray to the byte buffer
  mov rdi, r13
  mov rsi, r12
  call byte_buffer_push_barray

  mov rax, r14 ; We stashed return value in r14
  jmp .done

  .expand_parray:
  ;; If this is an empty parray, just output -1 and done
  cmp qword[r12], -1
  jne .not_empty

    ;; Save our data length to use as our buffer-relative pointer
    mov rdi, r13
    call byte_buffer_get_data_length
    mov r14, rax

    mov rdi, r13
    mov rsi, -1
    call byte_buffer_push_int64

    mov rax, r14
    jmp .done

  .not_empty:

  ;; Create byte buffer to attempt expansion
  ;; TODO using a new byte buffer each time isn't particularly efficient,
  ;; especially because not everything will expand.
  ;;
  ;; We should probably have a big buffer around just for these temps.
  ;; note that if this is done, below usage in .expand_parray_expanded
  ;; needs to be adjusted (currently uses tip of buffer to get macroexpansion
  ;; ptr)
  call byte_buffer_new
  mov rbx, rax

  ;; Try to expand this parray based on first element
  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, qword[r12+8]           ; name barray (first element of this parray)
  mov rdx, r12                    ; arg1 (*data) TODO: remove first element?
  mov rcx, rbx                    ; output buffer
  call macro_stack_call_by_name
  mov r15, rax ; r15 = expanded macro (if it expanded)
  cmp r15, -1
  je .expand_parray_nothing
  cmp rdx, 0
  je .expand_parray_not_expanded

  .expand_parray_expanded:
  ;; It expanded. Call self on the expansion, then output the returned pointer
  mov rdi, rbx
  call byte_buffer_get_buf
  add rax, r15

  mov rdi, rax
  mov rsi, r13
  call structural_macro_expand_relptr
  jmp .expand_parray_done

  .expand_parray_nothing:
    ;; This macro expanded to nothing. Return -1 as our nothing signal.
    mov rax, -1
    jmp .expand_parray_done

  .expand_parray_not_expanded:
  ;; It didn't expand, call structural_macro_expand_relptr on it's children,
  ;;   then output the data into the buffer and return the pointer

  mov r15, qword[r12] ; child count
  mov rcx, r15
  not r15
  add r12, 8 ; move past length
  mov rbp, rsp
  .children:
    cmp r15, 0
    je .children_break

    push rcx
    push rcx
    mov rdi, qword[r12]
    mov rsi, r13
    call structural_macro_expand_relptr
    pop rcx
    pop rcx

    ;; Handle nothing
    cmp rax, -1
    jne .child_not_nothing
    inc rcx ; decrement child count (but it's one's complement so inc)
    jmp .child_next
    .child_not_nothing:

    push rax
    push rax

    .child_next:
    add r12, 8
    dec r15
    jmp .children
    .children_break:

  mov r15, rcx

  ; Save our data length to use as our buffer-relative pointer
  mov rdi, r13
  call byte_buffer_get_data_length
  mov r14, rax

  ; Write length
  mov rdi, r13
  mov rsi, r15
  call byte_buffer_push_int64

  ; Write child pointers
  not r15
  mov rcx, rbp
  .write_ptrs:
    cmp r15, 0
    je .write_ptrs_break

    sub rcx, 16

    push rcx
    push rcx
    mov rdi, r13
    mov rsi, qword[rcx]
    call byte_buffer_push_int64
    pop rcx
    pop rcx

    dec r15
    jmp .write_ptrs
  .write_ptrs_break:

  ; Restore stack pointer
  mov rsp, rbp

  mov rax, r14
  ;jmp .expand_parray_done

  .expand_parray_done:
  push rax
  sub rsp, 8
  mov rdi, rbx
  call byte_buffer_free
  add rsp, 8
  pop rax
  ;jmp .done

  .done:
  add rsp, 8
  pop rbp
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

