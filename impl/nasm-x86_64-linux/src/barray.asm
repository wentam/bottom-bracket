section .text
global barray_new
global barray_deposit_bytes
global barray_equalp
extern malloc
extern assert_stack_aligned

;;; barray_new(length, *data)
;;;   Makes a new heap-allocated barray. Free with normal 'free'.
barray_new:
  push r12
  push r13
  push rbx
  mov r12, rsi ; data
  mov r13, rdi ; length

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Allocate
  add rdi, 8
  call malloc
  mov rbx, rax

  ;; Copy length
  mov qword[rbx], r13

  ;; Copy data
  mov rcx, 0 ; byte counter
  .copy_loop:
    cmp r13, 0
    je .copy_loop_break

    mov r8b, byte[r12+rcx]
    mov byte[rbx+rcx+8], r8b

    dec r13
    inc rcx
    jmp .copy_loop

  .copy_loop_break:

  mov rax, rbx
  pop rbx
  pop r13
  pop r12
  ret

;;; barray_deposit_bytes(barray*, to*)
;;;
;;;   Writes this barray's bytes (just the raw bytes, not the length) to the
;;    memory at to*.
barray_deposit_bytes:
  sub rsp, 8

  mov rdx, qword[rdi]
  add rdi, 8 ; move past length
  .loop:
  cmp rdx, 0
  jle .loop_break

  mov al, byte[rdi]
  mov byte[rsi], al

  inc rsi
  inc rdi
  dec rdx
  jmp .loop
  .loop_break:

  add rsp, 8
  ret

;;; barray_equalp(*barray, *barray) -> 0 or 1
;;;   Compares two barrays. Returns 1 if they are identical in both
;;;   length and contents. 0 otherwise.
barray_equalp:
  mov r8, qword[rdi] ; barray1 length
  mov r9, qword[rsi] ; barray2 length

  ;; Unless we otherwise determine it, we return 0
  mov rax, 0

  ;; If they differ in length, they're different
  cmp r8, r9
  jne .epilogue

  ;; Move past barray lengths
  add rdi, 8
  add rsi, 8

  mov rcx, r8
  shr rcx, 3 ; rcx = number of 8-byte blocks
  and r8, 7 ; remaining 0-7 bytes

  ;; Compare bulk in qword chunks
  .qword_loop:
    test rcx, rcx
    jz .qword_loop_break
    mov rdx, qword[rsi]
    cmp rdx, qword[rdi]
    jne .epilogue
    add rsi, 8
    add rdi, 8
    dec rcx
    jmp .qword_loop
  .qword_loop_break:

  ;; Compare tail bytes byte-by-byte (unrolled loop)
  %rep 7
    test r8, r8
    jz .byte_loop_break
    mov cl, byte[rdi]
    cmp byte[rsi], cl
    jne .epilogue
    inc rdi
    inc rsi
    dec r8
  %endrep

  .byte_loop_break:

  ;; If we ran out the loop - then we found no differences. result is 1.
  mov rax, 1

  .epilogue:
  ret
