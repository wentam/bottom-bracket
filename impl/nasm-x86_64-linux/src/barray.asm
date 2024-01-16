section .text
global barray_new
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
