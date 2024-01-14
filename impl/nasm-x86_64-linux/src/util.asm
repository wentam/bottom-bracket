;;; TODO function for linux errno to string

section .rodata
stack_unaligned_str: db "ERROR: stack not 16-byte-aligned at stack alignment assertion",10
stack_unaligned_str_len: equ $ - stack_unaligned_str

;;; Syscall numbers
sys_write:  equ 1
sys_read:   equ 0
sys_exit:   equ 60
sys_brk:    equ 12
sys_mmap:   equ 9
sys_munmap: equ 11
sys_mremap: equ 25

stdin_fd:  equ 0
stdout_fd: equ 1
stderr_fd: equ 2

%define MAP_ANONYMOUS  0x20
%define MAP_PRIVATE    0x02
%define PROT_READ      0x1
%define PROT_WRITE     0x2
%define MREMAP_MAYMOVE 0x1

section .text
global fn_write
global fn_error_exit
global fn_exit
global fn_read_char
global fn_write_char
global fn_malloc
global fn_realloc
global fn_free
global fn_write_as_base
global fn_digit_to_ascii
global fn_assert_stack_aligned
global fn_bindump
global fn_barray_equalp

extern fn_byte_buffer_new
extern fn_byte_buffer_free
extern fn_byte_buffer_push_byte
extern fn_byte_buffer_write_contents

;;; print(*string, len, fd)
;;;   Writes the string of bytes to fd. Returns 0 on error.
fn_write:
  push r12
  push r13
  push r14
  mov r13, rdi ; string
  mov r12, rsi ; string length
  mov r14, rdx ; fd

  fn_write_again:
  mov rdx, r12       ; String length
  mov rsi, r13       ; String
  mov rdi, r14       ; Output fd
  mov rax, sys_write ; syscall number
  syscall

  cmp rax, 0
  jl fn_write_err

  sub r12, rax
  add r13, rax
  cmp r12, 0
  jg fn_write_again

  fn_write_epilogue:
  pop r14
  pop r13
  pop r12
  ret

  fn_write_err:
  mov rax, 0
  jmp fn_write_epilogue

;;; error_exit(*string, len)
;;;   prints an error to stderr and exits
fn_error_exit:
  ;mov rdi, rdi
  ;mov rsi, rsi
  mov rdx, stderr_fd
  call fn_write

  mov rdi, 1
  call fn_exit
  ret

;;; exit(exit_code) - Exits the program with the given exit code
fn_exit:
                    ; rdi is already exit code
  mov rax, sys_exit ; syscall number
  syscall
  ret

;;; read_char(fd) -> char
;;;   Reads a single character from an FD and returns it
fn_read_char:
  mov rsi, rsp
  dec rsi
  mov rdx, 1
              ; fd already in rdi
  mov rax, sys_read
  syscall
  mov rax, [rsp-1]
  ret

;;; fn_write_char(char, fd) - Writes a single character to an FD
fn_write_char:
  push rdi

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rdi, rsp
  mov rdx, rsi
  mov rsi, 1
  call fn_write
  pop rdi
  ret

;;; malloc(size) -> ptr
;;;  Allocates memory. returns 0/NULL if allocation fails.
fn_malloc:
  sub rsp, 8
  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; mmap in a chunk of memory at requested size+8
  ;; The extra 8 bytes will be used to store the length of the allocation
  add rdi, 8        ; Make room for our metadata
  mov rsi, rdi      ; length
  mov rdi, 0        ; addr (NULL)
  mov rdx, (PROT_READ | PROT_WRITE)      ; protection flags
  mov r10, (MAP_PRIVATE | MAP_ANONYMOUS) ; flags
  mov r8,  -1       ; fd. -1 for portability with MAP_ANONYMOUS
  mov r9,  0        ; offset
  mov rax, sys_mmap ; syscall number
  syscall

  ;; If mmap gave us an error, proceed to failed codepath
  test rax, rax
  js   malloc_failed

  ;; Write the length of this allocation to the first 8 bytes.
  ;; The length will include the extra 8 bytes.
  mov qword [rax], rsi

  ;; Return a pointer to the block+8 so the user doesn't get our metadata
  add rax, 8

  add rsp, 8
  ret

  malloc_failed:
    mov rax, 0

    add rsp, 8
    ret

;;; free(ptr) -> int
;;;   Frees memory allocated with malloc. Returns 0 on success, -errno on error.
fn_free:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  sub rdi, 8           ; Walk back to the start of the mmap region
  mov rsi, qword [rdi] ; Grab our length from our metadata prefix
  mov rax, sys_munmap
  syscall

  add rsp, 8
  ret

;;; realloc(ptr, new_size) -> ptr
;;;   Reallocate memory to new_size.
;;;
;;;   After the allocation the pointer to the previous allocation is invalid.
;;;
;;;   Returns 0 (NULL pointer) on failure.
fn_realloc:
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; remap mmap region
  add rsi, 8
  sub rdi, 8              ; Walk back to the start of the mmap region
  mov rdx, rsi            ; New length from function argument
  mov rsi, qword [rdi]    ; Length from our metadata
  mov r10, MREMAP_MAYMOVE ; flags
  mov  r8, 0              ; new address (unused with current flags)
  mov rax, sys_mremap
  syscall

  ;; Failed codepath if realloc failed
  test rax, rax
  js realloc_failed

  ;; write new length to metadata
  mov qword [rax], rdx

  ;; Return mmaped region with metadata hidden
  add rax, 8

  add rsp, 8
  ret

  realloc_failed:
    mov rax, 0

    add rsp, 8
    ret

;;; barray_equalp(*barray, *barray) -> 0 or 1
;;;   Compares two barrays. Returns 1 if they are identical in both
;;;   length and contents. 0 otherwise.
fn_barray_equalp:
  mov r8, qword[rdi] ; barray1 length
  mov r9, qword[rsi] ; barray2 length

  ;; Unless we otherwise determine it, we return 0
  mov rax, 0

  ;; Move past barray lengths
  add rdi, 8
  add rsi, 8

  cmp r8, r9
  jne .epilogue

  .byte_loop:
    cmp r8, 0
    je .byte_loop_break

    ;; Compare the byte
    mov cl, byte[rdi+r8-1]
    cmp byte[rsi+r8-1], cl
    jne .epilogue

    dec r8
    jmp .byte_loop

  .byte_loop_break:

  ;; If we ran out the loop - then we found no differences. result is 1.
  mov rax, 1

  .epilogue:
  ret

;;; digit_to_ascii(int) -> char
;;;   Converts any numeric value representing a digit (up to base 36) to ASCII
;;;   (0-9 A-Z)
fn_digit_to_ascii:
  sub rsp, 8

  mov rax, rdi
  cmp rax, 9
  jle as_digit

  as_letter:
    sub rax, 10
    add rax, 'A'

    add rsp, 8
    ret

  as_digit:
    add rax, '0'

    add rsp, 8
    ret

;;; write_as_base(int64, base, fd, pad-to)
;;;   Writes a number to fd as a string in a specified base.
;;;   Works up to base 36 using 0-9 A-Z.
;;;
;;;   Pad-to specifies the minimum number of digits. Will be padded
;;;   by prefixing with zeros. 0 to disable padding.
;;;
;;;   Doesn't clobber rdi (handy for debugging)
fn_write_as_base:
  push r13
  push r12
  push rdi
  push r14
  sub rsp, 8

  mov r13, rdx ; Preserve output fd as we need rdx for other things
  mov r12, rsp ; Preserve stack ptr
  mov r14, rcx

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rax, rdi ; Division happens via rax so move to there
  mov r9, 0    ; loop index
  not_0:
    mov rdx, 0   ; Needed for single-register divide below
    div rsi      ; divide rdx:rax by rsi, rax: quotient, rdx: remainder

    ;; Convert to ASCII
    push rax     ; Preserve
    mov rdi, rdx ; Set our number as first arg to function call
    call fn_digit_to_ascii
    mov rdx, rax ; Assign return value as our number
    pop rax      ; Restore

    dec rsp
    mov byte[rsp], dl ; last byte of rdx

    inc r9 ; increment loop index
    cmp rax, 0
    jg not_0

  sub r14, r9 ; pad-to - current length
  pad:
    cmp r14, 0
    jle done_padding

    dec rsp
    mov byte[rsp], '0'
    dec r14
    inc r9
    jmp pad

  done_padding:

  ;; Print result
  mov rdi, rsp
  mov rsi, r9
  mov rdx, r13
  call fn_write

  mov rsp, r12; Restore stack ptr

  add rsp, 8
  pop r14
  pop rdi ; Restore
  pop r12 ; Restore
  pop r13 ; Restore
  ret

;;; TODO remove code duplication with the above
;;; write_as_base_bb(int64, base, *byte_buffer, pad-to)
;;;   Writes a number to byte buffer as a string in a specified base.
;;;   Works up to base 36 using 0-9 A-Z.
;;;
;;;   Pad-to specifies the minimum number of digits. Will be padded
;;;   by prefixing with zeros. 0 to disable padding.
;;;
;;;   Doesn't clobber rdi (handy for debugging)
fn_write_as_base_bb:
  push r13
  push r12
  push rdi
  push r14
  sub rsp, 8

  mov r13, rdx ; Byte buffer
  mov r12, rsp ; Preserve stack ptr
  mov r14, rcx

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rax, rdi ; Division happens via rax so move to there
  mov r9, 0    ; loop index
  bb_not_0:
    mov rdx, 0   ; Needed for single-register divide below
    div rsi      ; divide rdx:rax by rsi, rax: quotient, rdx: remainder

    ;; Convert to ASCII
    push rax     ; Preserve
    mov rdi, rdx ; Set our number as first arg to function call
    call fn_digit_to_ascii
    mov rdx, rax ; Assign return value as our number
    pop rax      ; Restore

    push rdx
    sub rsp, 8

    inc r9 ; increment loop index
    cmp rax, 0
    jg bb_not_0

  sub r14, r9 ; pad-to - current length
  bb_pad:
    cmp r14, 0
    jle bb_done_padding

    push '0'
    sub rsp, 8

    dec r14
    inc r9
    jmp bb_pad

  bb_done_padding:

  write_to_bb_loop:
  cmp r9, 0
  je write_to_bb_loop_break

  add rsp, 8
  pop rcx

  mov rdi, r13
  mov rsi, rcx
  call fn_byte_buffer_push_byte

  dec r9
  jmp write_to_bb_loop

  write_to_bb_loop_break:

  mov rsp, r12; Restore stack ptr

  add rsp, 8
  pop r14
  pop rdi ; Restore
  pop r12 ; Restore
  pop r13 ; Restore
  ret

;;; TODO: this really needs to be broken apart and documented better
;;; bindump(*data, len, fd, base)
;;;   Arbitrary-base hexdump-like function.
fn_bindump:
  push rbp
  push r12
  push r13
  push r14
  push r15
  push rbx
  mov rbp, rsp
  push rcx ; base. not enough registers, using stack.
  push rdx
  sub rsp, 8

  mov r12, rdi ; data
  mov r13, rsi ; len

  call fn_byte_buffer_new
  mov r14, rax ; byte buffer

  ;; Work out how much number padding we need without using 'log'
  ;; (because we don't have a log function currently)
  mov rax, 255
  mov rbx, 0
  mov rsi, qword[rbp-8] ; base
  mov r9, 0
  pad_calc_not_0:
    mov rdx, 0
    div rsi
    inc r9
    cmp rax, 0
    jg pad_calc_not_0

  push r9 ; padding needed

  ;; Work out how much padding we need to represent 2^(4*8) addresses
  mov rax, 4294967295
  mov rbx, 0
  mov rsi, qword[rbp-8] ; base
  mov r9, 0
  address_pad_calc_not_0:
    mov rdx, 0
    div rsi
    inc r9
    cmp rax, 0
    jg address_pad_calc_not_0

  push r9 ; address padding needed

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rbx, 0
  row_loop:
    cmp r13, 0
    je row_loop_break

    mov rdi, rbx
    mov rsi, qword[rbp-8]  ; base
    mov rdx, r14           ; byte buffer
    mov rcx, qword[rbp-40] ; padding
    call fn_write_as_base_bb

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call fn_byte_buffer_push_byte

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call fn_byte_buffer_push_byte

    push r13
    push r12
    mov r15, 16
    byte_loop:
      cmp r15, 0
      je byte_loop_break
      cmp r13, 0
      jne byte_loop_is_data

      byte_loop_is_not_data:
      mov rdi, qword[rbp-32]
      fill_space_loop:
        cmp rdi, 0
        jle break_fill_space_loop
        push rdi
        sub rsp, 8

        mov rdi, r14 ; byte buffer
        mov rsi, ' '
        call fn_byte_buffer_push_byte

        add rsp, 8
        pop rdi
        dec rdi
        jmp fill_space_loop

      break_fill_space_loop:

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call fn_byte_buffer_push_byte

      cmp r15, 9
      jne _no_extra_space

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call fn_byte_buffer_push_byte

      _no_extra_space:

      dec r15
      jmp byte_loop

      byte_loop_is_data:

      mov rdi, 0
      mov dil, byte[r12]
      mov rsi, qword[rbp-8]
      mov rdx, r14
      mov rcx, qword[rbp-32]
      call fn_write_as_base_bb

      cmp r15, 9
      jne no_extra_space

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call fn_byte_buffer_push_byte

      no_extra_space:

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call fn_byte_buffer_push_byte

      dec r13
      dec r15
      inc r12
      jmp byte_loop
    byte_loop_break:

    pop r12
    pop r13

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call fn_byte_buffer_push_byte


    mov rdi, r14 ; byte buffer
    mov rsi, '|'
    call fn_byte_buffer_push_byte

    mov r15, 16
    char_loop:
      cmp r13, 0
      je char_loop_break
      cmp r15, 0
      je char_loop_break

      mov rdi, 0
      mov dil, byte[r12]
      sub rdi, 32
      cmp rdi, 94
      jbe is_ascii

      mov rdi, r14 ; byte buffer
      mov rsi, '.'
      call fn_byte_buffer_push_byte

      jmp after_is_ascii

      is_ascii:
      mov rdi, r14 ; byte buffer
      xor rsi, rsi
      mov sil, byte[r12]
      call fn_byte_buffer_push_byte

      after_is_ascii:

      dec r13
      dec r15
      inc r12
      jmp char_loop
    char_loop_break:

  add rbx, 16


  mov rdi, r14 ; byte buffer
  mov rsi, '|'
  call fn_byte_buffer_push_byte

  mov rdi, r14 ; byte buffer
  mov rsi, 10
  call fn_byte_buffer_push_byte

  jmp row_loop
  row_loop_break:

  ;; Print out byte buffer contents
  mov rdi, r14
  mov rsi, qword[rbp-16]
  call fn_byte_buffer_write_contents

  ;; Free the byte buffer
  mov rdi, r14
  call fn_byte_buffer_free

  pop r9
  pop r9
  add rsp, 8
  pop rdx
  pop rcx
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;;; assert_stack_aligned()
;;;   asserts that rsp is 16-byte aligned at the callsite.
;;;
;;;   If it's not, will print an error message and 'int 3' to trigger a
;;;   break (or exit if no debugger is attached)
fn_assert_stack_aligned:
  sub rsp, 8 ; Make sure we're not un-aligning the stack ourselves.
             ; 'call' pushes a pointer to the stack, so we only need
             ; to sub 8 here.

  ;; ((15 & rsp) == 0) -> stack aligned
  mov rax, 15
  and rax, rsp
  cmp rax, 0
  je aligned

  ;; Not aligned
  mov rdi, stack_unaligned_str
  mov rsi, stack_unaligned_str_len
  mov rdx, stderr_fd
  call fn_write
  int 3

  aligned:

  add rsp, 8
  ret
