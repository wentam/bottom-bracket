section .text
global barray_new
global barray_deposit_bytes
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
