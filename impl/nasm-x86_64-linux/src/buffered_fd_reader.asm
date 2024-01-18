;;;; Buffered reader
;;;;
;;;; Reads from an fd in a buffered fashion - and allows 'peeking' at the next
;;;; char.

;;; TODO: maybe this should allow you to ask for a specific length
;;; of lookahead/lookbehind providing a nice APi for that.
;;;
;;; Could ask for 1024 ahead/behind at construction time for
;;; example.
;;;
;;; Would probably be best to implement as a circular buffer
;;; with a single pointer.
;;;
;;; This matters because this is probably going to become a public
;;; interface to reader macros.


section .text
global buffered_fd_reader_new
global buffered_fd_reader_free
global buffered_fd_reader_read_byte
global buffered_fd_reader_peek_byte
global buffered_fd_reader_consume_leading_whitespace
global BUFFERED_READER_EOF

extern malloc
extern free
extern realloc
extern error_exit
extern assert_stack_aligned

section .rodata

sys_read:  equ 0x00
BUFFERED_READER_EOF: equ 256
malloc_failed_error_str: db "ERROR: Failed to allocate read buffer (out of memory?)",10
malloc_failed_error_str_len: equ $ - malloc_failed_error_str

section .text

;;; struct buffered_fd_reader {
;;;   int64_t fd;     // File descriptor to read data from
;;;   char* read_ptr; // Pointer to the next byte to read
;;;   char* end_ptr;  // Pointer to the end of valid data + 1
;;;                   // (first invalid byte) in the buffer
;;;
;;;   char buf[READ_BUFFER_SIZE] // Buffer (flat in struct, not pointer)
;;; }

;;; Offsets for the elements in above struct. Defining them here allows us
;;; to easily modify the struct definition later if needed.
%define BUFFERED_READER_FD_OFFSET 0
%define BUFFERED_READER_READ_PTR_OFFSET 8
%define BUFFERED_READER_END_PTR_OFFSET 16
%define BUFFERED_READER_BUF_OFFSET 24

%define READ_BUFFER_SIZE 4096 ; For simplicity read buffers are constant size
%define BUFFERED_READER_SIZE (READ_BUFFER_SIZE + 24)

%define NEWLINE 10
%define TAB 9

;;; buffered_fd_reader_new(fd)
;;;   Creates a new buffered reader.
;;;
;;;   Free with buffered_fd_reader_free when done.
buffered_fd_reader_new:
  push r12

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r12, rdi

  ;; Allocate the struct
  mov rdi, BUFFERED_READER_SIZE
  call malloc

  ;; Error and exit if malloc failed
  cmp rax, 0
  jne .good_malloc

  mov rdi, malloc_failed_error_str
  mov rsi, malloc_failed_error_str_len
  call error_exit

  .good_malloc:

  ;; Initialize the members
  mov qword [rax+BUFFERED_READER_FD_OFFSET], r12
  mov qword [rax+BUFFERED_READER_READ_PTR_OFFSET], 0
  mov qword [rax+BUFFERED_READER_END_PTR_OFFSET], 0

  pop r12
  ret

;;; buffered_fd_reader_free(*buffered_fd_reader)
;;;   Frees a buffered reader.
buffered_fd_reader_free:
  sub rsp, 8
  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  call free
  add rsp, 8
  ret

;;; buffered_fd_reader_read_byte(*buffered_fd_reader)
;;;   Reads a byte.
buffered_fd_reader_read_byte:
  push r12
  push r13
  sub rsp, 8
  mov r12, rdi                                   ; Struct pointer
  mov r13, qword [r12+BUFFERED_READER_FD_OFFSET] ; fd

  ;; Decide if we need to refill the buffer
  mov rdi, qword [r12+BUFFERED_READER_READ_PTR_OFFSET]
  cmp rdi, qword [r12+BUFFERED_READER_END_PTR_OFFSET]
  jne .do_read ; read pointer != end of data -> skip refill

  ;; Refill buffer from fd
  mov rsi, r12                        ; Struct pointer
  add rsi, BUFFERED_READER_BUF_OFFSET ; Move to start of the buffer
  mov rdi, r13                        ; FD to read from
  mov rdx, READ_BUFFER_SIZE           ; Length to read
  mov rax, sys_read                   ; syscall number
  syscall

  ;; If sys_read returns zero, take EOF codepath
  cmp rax, 0
  je .epilogue

  ;; Set read pointer to front of buffer
  mov qword [r12+BUFFERED_READER_READ_PTR_OFFSET], rsi

  ;; Set end pointer to end of valid data based upon sys_read return value
  mov rdi, rsi
  add rdi, rax
  mov qword [r12+BUFFERED_READER_END_PTR_OFFSET], rdi

  .do_read:
  mov rsi, qword [r12+BUFFERED_READER_READ_PTR_OFFSET] ; Obtain read pointer
  xor rax, rax                                         ; Zero rax
  mov  al, byte [rsi]                                  ; Read at read pointer
  inc qword [r12+BUFFERED_READER_READ_PTR_OFFSET]      ; increment read pointer

  add rsp, 8
  pop r13
  pop r12
  ret

  .epilogue:
  mov rax, BUFFERED_READER_EOF
  add rsp, 8
  pop r13
  pop r12
  ret

;;; buffered_fd_reader_peek_byte(*buffered_fd_reader)
;;;   Returns the next byte without consuming it.
buffered_fd_reader_peek_byte:
  push r12
  mov r12, rdi ; Preserve struct pointer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  call buffered_fd_reader_read_byte

  ;; EOF is handled specially by read_byte and doesn't add anything to the
  ;; buffer or move the pointer. Hence skip decrement if it's EOF.
  cmp rax, BUFFERED_READER_EOF
  je .nodec

  dec qword[r12+BUFFERED_READER_READ_PTR_OFFSET]

  .nodec:

  pop r12
  ret

;;; buffered_fd_reader_consume_leading_whitespace(*buffered_fd_reader)
;;;   Consumes all of the whitespace at the front of the read buffer.
;;;
;;;   Returns the next (non-whitespace) char without consuming it from the read
;;;   buffer.
buffered_fd_reader_consume_leading_whitespace:
  push r12
  mov r12, rdi ; Struct pointer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  .consume_loop:
  mov rdi, r12
  call buffered_fd_reader_peek_byte
  cmp rax, ' '
  je .found_whitespace
  cmp rax, NEWLINE
  je .found_whitespace
  cmp rax, TAB
  je .found_whitespace

  pop r12
  ret

  .found_whitespace:
  mov rdi, r12
  call buffered_fd_reader_read_byte ; consume
  jmp .consume_loop

