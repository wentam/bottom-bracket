section .rodata
;;; Syscall numbers
sys_write: equ 1
sys_read:  equ 0
sys_exit:  equ 60
sys_brk:   equ 12
sys_mmap:  equ 9


stdin_fd: equ 0
stdout_fd: equ 1
stderr_fd: equ 2

%define MAP_ANONYMOUS 0x20
%define MAP_PRIVATE 0x02
%define PROT_READ 0x1
%define PROT_WRITE 0x2

section .text
global fn_print
global fn_exit
global fn_read_char
global fn_write_char
global fn_malloc
global fn_write_as_base
global fn_digit_to_ascii

;;; print(string, len, fd) - Outputs given string to fd
fn_print:
  mov r10, rdx       ; We're about to clobber rdx, move to r10
  mov rdx, rsi       ; String length
  mov rsi, rdi       ; String
  mov rdi, r10       ; Output fd
  mov rax, sys_write ; syscall number
  syscall
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
  dec rsp
  mov byte [rsp], dil
  mov rdi, rsp
  mov rdx, rsi
  mov rsi, 1
  call fn_print
  inc rsp
  ret

;;; malloc(size) -> ptr
;;;  Allocates memory. returns 0/NULL if allocation fails.
fn_malloc:
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
  ret

  malloc_failed:
    mov rax, 0
    ret

;;; TODO
;;; free(ptr)
;;;
fn_free:
  ret

;;; TODO realloc
;;; TODO linux errno to string

;;; digit_to_ascii(int) -> char
;;;   Converts any numeric value representing a digit (up to base 36) to ASCII
;;;   (0-9 A-Z)
fn_digit_to_ascii:
  mov rax, rdi
  cmp rax, 9
  jle as_digit

  as_letter:
    sub rax, 10
    add rax, 'A'
    ret

  as_digit:
    add rax, '0'
    ret

;;; write_as_base(int, base, fd)
;;;   Writes a number to fd as a string in a specified base.
;;;   Works up to base 36 using 0-9 A-Z.
;;;
;;;   Doesn't clobber rdi (handy for debugging)
fn_write_as_base:
  push r13 ; Preserve
  push r12 ; Preserve
  push rdi ; Preserve

  mov r13, rdx ; Preserve output fd as we need rdx for other things
  mov r12, rsp ; Preserve stack ptr
  mov rax, rdi ; Division happens via rax so move to there
  mov r9, 0    ; loop index
  not_0:
    mov rdx, 0   ; Needed for single-register divide below
    div rsi      ; divide rdx:rax by rcx, rax: quotient, rdx: remainder

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

  ;; Print result
  mov rdi, rsp
  mov rsi, r9
  mov rdx, r13
  call fn_print

  mov rsp, r12; Restore stack ptr

  pop rdi ; Restore
  pop r12 ; Restore
  pop r13 ; Restore
  ret

