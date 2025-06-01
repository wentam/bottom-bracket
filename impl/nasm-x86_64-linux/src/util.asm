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
%define PROT_EXEC      0x4
%define MREMAP_MAYMOVE 0x1

section .text
global write
global error_exit
global exit
global read_char
global write_char
extern malloc
extern realloc
extern free
global write_as_base
global parse_uint
global digit_to_ascii
global ascii_to_digit
global assert_stack_aligned
global bindump
global alpha36p
global alpha10p
global byte_in_barray_p
global visible_char_p
global compare_barrays
global rel_to_abs

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_get_buf
extern byte_buffer_push_byte
extern byte_buffer_push_barray
extern byte_buffer_write_contents

;;; print(*string, len, fd)
;;;   Writes the string of bytes to fd. Returns 0 on error.
write:
  push r12
  push r13
  push r14
  mov r13, rdi ; string
  mov r12, rsi ; string length
  mov r14, rdx ; fd

  .write_again:
  mov rdx, r12       ; String length
  mov rsi, r13       ; String
  mov rdi, r14       ; Output fd
  mov rax, sys_write ; syscall number
  syscall

  cmp rax, 0
  jl .write_err

  sub r12, rax
  add r13, rax
  cmp r12, 0
  jg .write_again

  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

  .write_err:
  mov rax, 0
  jmp .epilogue

;;; error_exit(*string, len)
;;;   prints an error to stderr and exits
error_exit:
  ;mov rdi, rdi
  ;mov rsi, rsi
  mov rdx, stderr_fd
  call write

  mov rdi, 1
  call exit
  ret

;;; exit(exit_code) - Exits the program with the given exit code
exit:
                    ; rdi is already exit code
  mov rax, sys_exit ; syscall number
  syscall
  ret

;;; read_char(fd) -> char
;;;   Reads a single character from an FD and returns it
read_char:
  mov rsi, rsp
  dec rsi
  mov rdx, 1
              ; fd already in rdi
  mov rax, sys_read
  syscall
  mov rax, [rsp-1]
  ret

;;; write_char(char, fd) - Writes a single character to an FD
write_char:
  push rdi

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rdi, rsp
  mov rdx, rsi
  mov rsi, 1
  call write
  pop rdi
  ret

;;; malloc(size) -> ptr
;;;  Allocates memory. returns 0/NULL if allocation fails.
;malloc:
;  sub rsp, 8
;  %ifdef ASSERT_STACK_ALIGNMENT
;  call assert_stack_aligned
;  %endif
;
;  ;; mmap in a chunk of memory at requested size+8
;  ;; The extra 8 bytes will be used to store the length of the allocation
;  add rdi, 8        ; Make room for our metadata
;  mov rsi, rdi      ; length
;  mov rdi, 0        ; addr (NULL)
;  ;; TODO: don't exec by default, set up a path such that macro allocations
;  ;; can ask for executable
;  mov rdx, (PROT_READ | PROT_WRITE | PROT_EXEC) ; protection flags
;  mov r10, (MAP_PRIVATE | MAP_ANONYMOUS) ; flags
;  mov r8,  -1       ; fd. -1 for portability with MAP_ANONYMOUS
;  mov r9,  0        ; offset
;  mov rax, sys_mmap ; syscall number
;  syscall
;
;  ;; If mmap gave us an error, proceed to failed codepath
;  test rax, rax
;  js   .failed
;
;  ;; Write the length of this allocation to the first 8 bytes.
;  ;; The length will include the extra 8 bytes.
;  mov qword [rax], rsi
;
;  ;; Return a pointer to the block+8 so the user doesn't get our metadata
;  add rax, 8
;
;  add rsp, 8
;  ret
;
;  .failed:
;    mov rax, 0
;
;    add rsp, 8
;    ret

;;; free(ptr) -> int
;;;   Frees memory allocated with malloc. Returns 0 on success, -errno on error.
;free:
;  sub rsp, 8
;
;  %ifdef ASSERT_STACK_ALIGNMENT
;  call assert_stack_aligned
;  %endif
;
;  sub rdi, 8           ; Walk back to the start of the mmap region
;  mov rsi, qword [rdi] ; Grab our length from our metadata prefix
;  mov rax, sys_munmap
;  syscall
;
;  add rsp, 8
;  ret

;;; realloc(ptr, new_size) -> ptr
;;;   Reallocate memory to new_size.
;;;
;;;   After the allocation the pointer to the previous allocation is invalid.
;;;
;;;   Returns 0 (NULL pointer) on failure.
;realloc:
;  sub rsp, 8
;
;  %ifdef ASSERT_STACK_ALIGNMENT
;  call assert_stack_aligned
;  %endif
;
;  ;; remap mmap region
;  add rsi, 8
;  sub rdi, 8              ; Walk back to the start of the mmap region
;  mov rdx, rsi            ; New length from function argument
;  mov rsi, qword [rdi]    ; Length from our metadata
;  mov r10, MREMAP_MAYMOVE ; flags
;  mov  r8, 0              ; new address (unused with current flags)
;  mov rax, sys_mremap
;  syscall
;
;  ;; Failed codepath if realloc failed
;  test rax, rax
;  js .failed
;
;  ;; write new length to metadata
;  mov qword [rax], rdx
;
;  ;; Return mmaped region with metadata hidden
;  add rax, 8
;
;  add rsp, 8
;  ret
;
;  .failed:
;    mov rax, 0
;
;    add rsp, 8
;    ret

;;; digit_to_ascii(int) -> char
;;;   Converts any numeric value representing a digit (up to base 36) to ASCII
;;;   (0-9 A-Z)
digit_to_ascii:
  sub rsp, 8

  mov rax, rdi
  cmp rax, 9
  jle .as_digit

  .as_letter:
    sub rax, 10
    add rax, 'A'

    add rsp, 8
    ret

  .as_digit:
    add rax, '0'

    add rsp, 8
    ret

;;; alpha36p(byte) -> int
;;;   1 if byte represents the chars A-Z a-z 0-9, else 0
alpha36p:
  mov rcx, 1
  mov rax, 0

  sub rdi, 48 ; move to '0' char
  cmp rdi, 10
  cmovb rax, rcx

  sub rdi, 17 ; move to 'A' char
  cmp rdi, 26
  cmovb rax, rcx

  sub rdi, 32 ; move to 'a' char
  cmp rdi, 26
  cmovb rax, rcx

  ret

;;; visible_char_p(byte) -> int
;;;   1 if byte represents a visible non-whitespace ascii char, else 0
visible_char_p:
  mov rcx, 1
  mov rax, 0

  sub rdi, 33
  cmp rdi, 94
  cmovb rax, rcx

  ret

;;; byteinbarrayp(byte, *barray)
;;;   1 if byte appears at least once in *barray, else 0.
byte_in_barray_p:
  mov rcx, qword[rsi] ; length
  add rsi, 8          ; move past length

  .loop:
  cmp rcx, 0
  je .break

  cmp dil, byte[rsi]
  je .match

  dec rcx
  inc rsi
  jmp .loop

  .break:
  mov rax, 0
  ret

  .match:
  mov rax, 1
  ret

;;; alpha10p(byte) -> int
;;;   1 if byte represents the chars 0-9, else 0
alpha10p:
  mov rcx, 1
  mov rax, 0

  sub rdi, 48 ; move to '0' char
  cmp rdi, 10
  cmovb rax, rcx
  ret

;;; ascii_to_digit(byte)
;;;   Converts an ascii byte (0-9 A-Z a-z) to the digit it represents.
;;;   (up to base 36)
;;;
;;;   a-z is equivalent to A-Z
ascii_to_digit:
  mov rax, rdi

  cmp rax, 57
  jg .as_uppercase_letter

  sub rax, 48
  ret

  .as_uppercase_letter:
  cmp rax, 90
  jg .as_lowercase_letter

  sub rax, 55
  ret

  .as_lowercase_letter:
  sub rax, 87
  ret

;;; parse_uint(*barray_string, base) -> int
;;;   Parses an unsigned integer from *barray_string as base
parse_uint:
  push r12
  push r13
  push r14
  push r15
  push rbx
  mov r12, rdi ; string
  mov r13, rsi ; base

  mov r15, qword[r12] ; get length
  add r12, 8          ; move past length

  ;; Loop working right-to-left
  xor r14, r14 ; result
  mov rbx, 1    ; multiplier
  .loop:
    cmp r15, 0
    je .break

    ;; Parse digit
    xor rdi, rdi
    mov dil, byte[r12+r15-1]
    call ascii_to_digit

    ;; TODO error if digit >= base?
    ;; TODO error if digit < 0?

    ;; Multiply digit by multiplier (digit*base*position)
    mul rbx

    ;; Add to result
    add r14, rax

    ;; Update multiplier
    mov rax, rbx
    mul r13
    mov rbx, rax

    ;; Next byte
    dec r15
    jmp .loop

  .break:

  mov rax, r14
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; write_as_base(int64, base, fd, pad-to)
;;;   Writes a number to fd as a string in a specified base.
;;;   Works up to base 36 using 0-9 A-Z.
;;;
;;;   Pad-to specifies the minimum number of digits. Will be padded
;;;   by prefixing with zeros. 0 to disable padding.
;;;
;;;   Doesn't clobber rdi (handy for debugging)
write_as_base:
  push r13
  push r12
  push rdi
  push r14
  sub rsp, 8

  mov r13, rdx ; Preserve output fd as we need rdx for other things
  mov r12, rsp ; Preserve stack ptr
  mov r14, rcx

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rax, rdi ; Division happens via rax so move to there
  mov r9, 0    ; loop index
  .not_0:
    mov rdx, 0   ; Needed for single-register divide below
    div rsi      ; divide rdx:rax by rsi, rax: quotient, rdx: remainder

    ;; Convert to ASCII
    push rax     ; Preserve
    mov rdi, rdx ; Set our number as first arg to function call
    call digit_to_ascii
    mov rdx, rax ; Assign return value as our number
    pop rax      ; Restore

    dec rsp
    mov byte[rsp], dl ; last byte of rdx

    inc r9 ; increment loop index
    cmp rax, 0
    jg .not_0

  sub r14, r9 ; pad-to - current length
  .pad:
    cmp r14, 0
    jle .done_padding

    dec rsp
    mov byte[rsp], '0'
    dec r14
    inc r9
    jmp .pad

  .done_padding:

  ;; Print result
  mov rdi, rsp
  mov rsi, r9
  mov rdx, r13
  call write

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
write_as_base_bb:
  push r13
  push r12
  push rdi
  push r14
  sub rsp, 8

  mov r13, rdx ; Byte buffer
  mov r12, rsp ; Preserve stack ptr
  mov r14, rcx

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rax, rdi ; Division happens via rax so move to there
  mov r9, 0    ; loop index
  .not_0:
    mov rdx, 0   ; Needed for single-register divide below
    div rsi      ; divide rdx:rax by rsi, rax: quotient, rdx: remainder

    ;; Convert to ASCII
    push rax     ; Preserve
    mov rdi, rdx ; Set our number as first arg to function call
    call digit_to_ascii
    mov rdx, rax ; Assign return value as our number
    pop rax      ; Restore

    push rdx
    sub rsp, 8

    inc r9 ; increment loop index
    cmp rax, 0
    jg .not_0

  sub r14, r9 ; pad-to - current length
  .pad:
    cmp r14, 0
    jle .done_padding

    push '0'
    sub rsp, 8

    dec r14
    inc r9
    jmp .pad

  .done_padding:

  .write_to_bb_loop:
  cmp r9, 0
  je .write_to_bb_loop_break

  add rsp, 8
  pop rcx

  mov rdi, r13
  mov rsi, rcx
  call byte_buffer_push_byte

  dec r9
  jmp .write_to_bb_loop

  .write_to_bb_loop_break:

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
bindump:
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

  call byte_buffer_new
  mov r14, rax ; byte buffer

  ;; Work out how much number padding we need without using 'log'
  ;; (because we don't have a log function currently)
  mov rax, 255
  mov rbx, 0
  mov rsi, qword[rbp-8] ; base
  mov r9, 0
  .pad_calc_not_0:
    mov rdx, 0
    div rsi
    inc r9
    cmp rax, 0
    jg .pad_calc_not_0

  push r9 ; padding needed

  ;; Work out how much padding we need to represent 2^(4*8) addresses
  mov rax, 4294967295
  mov rbx, 0
  mov rsi, qword[rbp-8] ; base
  mov r9, 0
  .address_pad_calc_not_0:
    mov rdx, 0
    div rsi
    inc r9
    cmp rax, 0
    jg .address_pad_calc_not_0

  push r9 ; address padding needed

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rbx, 0
  .row_loop:
    cmp r13, 0
    je .row_loop_break

    mov rdi, rbx
    mov rsi, qword[rbp-8]  ; base
    mov rdx, r14           ; byte buffer
    mov rcx, qword[rbp-40] ; padding
    call write_as_base_bb

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call byte_buffer_push_byte

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call byte_buffer_push_byte

    push r13
    push r12
    mov r15, 16
    .byte_loop:
      cmp r15, 0
      je .byte_loop_break
      cmp r13, 0
      jne .byte_loop_is_data

      .byte_loop_is_not_data:
      mov rdi, qword[rbp-32]
      .fill_space_loop:
        cmp rdi, 0
        jle .break_fill_space_loop
        push rdi
        sub rsp, 8

        mov rdi, r14 ; byte buffer
        mov rsi, ' '
        call byte_buffer_push_byte

        add rsp, 8
        pop rdi
        dec rdi
        jmp .fill_space_loop

      .break_fill_space_loop:

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call byte_buffer_push_byte

      cmp r15, 9
      jne .no_extra_space

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call byte_buffer_push_byte

      .no_extra_space:

      dec r15
      jmp .byte_loop

      .byte_loop_is_data:

      mov rdi, 0
      mov dil, byte[r12]
      mov rsi, qword[rbp-8]
      mov rdx, r14
      mov rcx, qword[rbp-32]
      call write_as_base_bb

      cmp r15, 9
      jne ._no_extra_space

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call byte_buffer_push_byte

      ._no_extra_space:

      mov rdi, r14 ; byte buffer
      mov rsi, ' '
      call byte_buffer_push_byte

      dec r13
      dec r15
      inc r12
      jmp .byte_loop
    .byte_loop_break:

    pop r12
    pop r13

    mov rdi, r14 ; byte buffer
    mov rsi, ' '
    call byte_buffer_push_byte


    mov rdi, r14 ; byte buffer
    mov rsi, '|'
    call byte_buffer_push_byte

    mov r15, 16
    .char_loop:
      cmp r13, 0
      je .char_loop_break
      cmp r15, 0
      je .char_loop_break

      mov rdi, 0
      mov dil, byte[r12]
      sub rdi, 32
      cmp rdi, 94
      jbe .is_ascii

      mov rdi, r14 ; byte buffer
      mov rsi, '.'
      call byte_buffer_push_byte

      jmp .after_is_ascii

      .is_ascii:
      mov rdi, r14 ; byte buffer
      xor rsi, rsi
      mov sil, byte[r12]
      call byte_buffer_push_byte

      .after_is_ascii:

      dec r13
      dec r15
      inc r12
      jmp .char_loop
    .char_loop_break:

  add rbx, 16


  mov rdi, r14 ; byte buffer
  mov rsi, '|'
  call byte_buffer_push_byte

  mov rdi, r14 ; byte buffer
  mov rsi, 10
  call byte_buffer_push_byte

  jmp .row_loop
  .row_loop_break:

  ;; Print out byte buffer contents
  mov rdi, r14
  mov rsi, qword[rbp-16]
  call byte_buffer_write_contents

  ;; Free the byte buffer
  mov rdi, r14
  call byte_buffer_free

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
assert_stack_aligned:
  push rbp
  push rax
  push rcx
  push rdx
  push rbx
  push rsi
  push rdi
  push r8
  push r9
  push r10
  push r11
  push r12
  push r13
  push r14
  push r15

  ;; ((15 & rsp) == 0) -> stack aligned
  mov rax, 15
  and rax, rsp
  cmp rax, 0
  je .aligned

  ;; Not aligned
  mov rdi, stack_unaligned_str
  mov rsi, stack_unaligned_str_len
  mov rdx, stderr_fd
  call write
  int3

  .aligned:

  pop r15
  pop r14
  pop r13
  pop r12
  pop r11
  pop r10
  pop r9
  pop r8
  pop rdi
  pop rsi
  pop rbx
  pop rdx
  pop rcx
  pop rax
  pop rbp
  ret

;;; TODO
;;; compare_barrays(barray_1*, barray_2*)
;;;   returns 1 if barrays are identical, else 0
compare_barrays:
  sub rsp, 8

  ;; TODO assert stack aligned

  ;; Compare lengths
  mov rdx, qword[rsi]
  cmp qword[rdi], rdx
  mov rax, 0
  jne .epilogue

  ;; Same length, compare bytes

  mov rdx, qword[rsi]  ; length
  mov r11, rdi ; pointer to byte of first array
  add r11, 8   ; move past length
  mov r10, rsi ; pointer to byte of second array
  add r10, 8   ; move past length
  .cmp_loop:
    mov r9b, byte[r10]
    mov r8b, byte[r11]
    cmp r9b, r8b
    mov rax, 0
    jne .epilogue

    inc r11
    inc r10
    dec rdx
    cmp rdx, 0
    jne .cmp_loop

  mov rax, 1

  .epilogue:
  add rsp, 8
  ret

;;; rel_to_abs(*structure, *byte_buffer)
;;;   Recursively modifies pointers in a structure that uses buffer-relative
;;;   pointers to convert them to absolute.
;;;
;;;   The structure's data must be entirely contained within the byte buffer and use
;;;   pointers relative to the start of that buffer for this to make any sense.
rel_to_abs:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  cmp rdi, 0
  je .epilogue

  mov r12, rdi ; read result ptr
  mov r13, rsi ; byte buffer

  ;; Start of actual buffer -> r14
  mov rdi, r13
  call byte_buffer_get_buf
  mov r14, rax

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r15, qword[r12] ; Length of parray/barray -> r15

  ;; If this is a barray, do nothing
  cmp r15, 0
  jge .epilogue

  not r15 ; Make parray length positive

  ;; If this is a parray, recursively convert
  add r12, 8 ; move past parray length

  .convert_loop:
    cmp r15, 0
    je .convert_loop_break

    add qword[r12], r14

    mov rdi, qword[r12]
    mov rsi, r13
    call rel_to_abs

    add r12, 8
    dec r15
    jmp .convert_loop
  .convert_loop_break:

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; This is my spot for having nasm assemble random things for me lel
tmpaoeu:
  mov rcx, 0
  ret

