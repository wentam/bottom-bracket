section .text
global structural_macro_expand
global structural_macro_expand_relptr
global structural_macro_expand_tail

extern byte_buffer_get_buf
extern byte_buffer_get_data_length
extern byte_buffer_push_barray
extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_push_int64
extern _relative_to_abs

extern macro_stack_structural

extern kv_stack_value_by_key

extern write_as_base
extern write_char

extern parray_tail_new

extern free

section .rodata

section .text

structural_macro_expand:
  push r12
  push r13
  push r14

  mov r12, rdi  ; data
  mov r13, rsi  ; output byte buffer
  ;mov rdx, rdx ; cp_shy_greedy
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

;;; structural_macro_expand_relptr(*data, *output_byte_buffer, shy_greedy) -> ptr
;;;   Produces a recursively (structural) macroexpanded version of *data in
;;;   *output_byte_buffer.
;;;
;;;   If cp_shy_greedy is cp (0), nothing will be expanded and we act as a recursive copy.
;;;   If cp_shy_greedy is shy (1), we will only expand the first element of each parray.
;;;   If cp_shy_greedy is greedy (2), everything will be expanded.
;;;   TODO make it so if it's 3, we do macroexpand-1
;;;
;;;   If you're not sure, you probably want a greedy expand.
;;;
;;;   To understarnd why 'shy' expansions are needed, look at how aarrp/with-macros manages
;;;   to behave like let* where each macro definition can use the last.
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

  mov rax, -1
  cmp rdi, 0 ; If data is NULL, return -1 for no data
  je .done

  mov r12, rdi ; data
  mov r13, rsi ; output byte buffer
  mov r14, rdx ; shy_greedy

  mov rdi, qword[r12] ; length of first thing in data
  cmp rdi, 0
  jl .expand_parray

  .expand_barray:
  ;; Save our data length to use as our buffer-relative pointer
  mov rdi, r13
  call byte_buffer_get_data_length
  push rax
  sub rsp, 8

  ;; Push this barray to the byte buffer
  mov rdi, r13
  mov rsi, r12
  call byte_buffer_push_barray

  add rsp, 8
  pop rax
  jmp .done

  .expand_parray:
  ;; If this is an empty parray, just output -1 and done
  cmp qword[r12], -1
  jne .not_empty

    ;; Save our data length to use as our buffer-relative pointer
    mov rdi, r13
    call byte_buffer_get_data_length
    push rax
    sub rsp, 8

    mov rdi, r13
    mov rsi, -1
    call byte_buffer_push_int64

    add rsp, 8
    pop rax
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

  ;; Skip expansion if we're in copy mode
  cmp r14, 0
  je .expand_parray_not_expanded

  ;; Try to expand this parray based on first element
  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, qword[r12+8]           ; name barray (first element of this parray)
  call kv_stack_value_by_key
  mov rdi, r12                    ; arg1 (*data)
  mov rsi, rbx                    ; output buffer
  mov rdx, rax
  cmp rax, 0
  je .nullfunc
  push rdx
  sub rsp, 8
  call qword[rax+8]
  add rsp, 8
  pop rdx
  .nullfunc:
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
  mov rdx, r14
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
    mov rdx, r14

    ;; If we're in shy mode (r14 == 1) and this isn't the first child,
    ;; set rdx to 0 for copy expansion.
    cmp r14, 1
    jne .not_copy_exp
    mov rax, rcx
    not rax
    cmp r15, rax
    je .not_copy_exp

    mov rdx, 0
    .not_copy_exp:

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


;;; structural_macro_expand_tail(*parray, *output_byte_buffer)
;;;   Macroexpands input parray excluding the first element of the parray.
;;;
;;;   Undefined behavior if input isn't a parray.
structural_macro_expand_tail:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; data
  mov r13, rsi ; output byte buffer
  mov rbx, rdx ; cp_shy_greedy

  ;; Compute tail
  mov rdi, r12
  call parray_tail_new
  mov r14, rax ; r14 = tail of parray

  ;; Macroexpand
  mov rdi, r14
  mov rsi, r13
  mov rdx, rbx
  call structural_macro_expand
  mov r15, rax ; r15 = macroexpanded tail

  ;; Free tail
  mov rdi, r14
  call free

  mov rax, r15
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret
