section .text
global parray_tail_new

extern malloc

;;; parray_tail_new(*parray)
;;;   Must free result with free() when done.
parray_tail_new:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input parray

  ;; If our source parray is zero-length, just write -1 (for zero-length output)
  ;; and return.
  mov rdi, qword[r12]
  cmp rdi, -1
  jne .nonzero

  mov rdi, 8
  call malloc
  mov r13, rax
  mov qword[r13], -1
  jmp .done

  .nonzero:

  ;; Allocate output
  mov rdi, qword[r12] ; Length of original parray
  not rdi             ; Undo one's complement
  shl rdi, 8          ; * 8 because we need to know how many bytes
  call malloc
  mov r13, rax

  ;; Write length
  mov rdi, qword[r12]
  inc rdi
  mov qword[r13], rdi

  ;; Copy all pointers in parray aside from the first
  mov rdi, qword[r12]
  not rdi
  dec rdi

  mov rsi, r13
  add rsi, 8

  mov rcx, r12
  add rcx, 16

  .copy_loop:
  cmp rdi, 0
  je .done

  mov r8, qword[rcx]
  mov qword[rsi], r8

  add rcx, 8
  add rsi, 8
  dec rdi
  jmp .copy_loop

  .done:
  mov rax, r13
  add rsp, 8
  pop r13
  pop r12
  ret
