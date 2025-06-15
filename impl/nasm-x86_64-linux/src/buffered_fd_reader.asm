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
;;;   int64_t fd;   // File descriptor to read data from
;;;   u32 read_ptr; // rel pointer to the next byte to read
;;;   u32 end_ptr;  // rel pointer to the end of valid data + 1
;;;                 // (first invalid byte) in the buffer
;;;
;;;   char buf[READ_BUFFER_SIZE] // Buffer (flat in struct, not pointer)
;;; }

;;; Offsets for the elements in above struct. Defining them here allows us
;;; to easily modify the struct definition later if needed.
%define BUFFERED_READER_FD_OFFSET 0
%define BUFFERED_READER_READ_PTR_OFFSET 8
%define BUFFERED_READER_END_PTR_OFFSET 12
%define BUFFERED_READER_BUF_OFFSET 16

%define READ_BUFFER_SIZE 65536
%define BUFFERED_READER_SIZE (READ_BUFFER_SIZE + BUFFERED_READER_BUF_OFFSET)

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
  mov qword[rax+BUFFERED_READER_FD_OFFSET], r12
  mov dword[rax+BUFFERED_READER_READ_PTR_OFFSET], 0
  mov dword[rax+BUFFERED_READER_END_PTR_OFFSET], 0

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
  ;; Decide if we need to refill the buffer
  ;;
  ;; NOTE: CPU seems to do better if we use two movs instead of use the end ptr directly in the
  ;; compare, probably because it's easier for it to realize it can load in parallel.

  mov ecx, dword[rdi+BUFFERED_READER_READ_PTR_OFFSET]
  mov eax, dword[rdi+BUFFERED_READER_END_PTR_OFFSET]
  cmp ecx, eax                                        ; Compare offsets
  je .do_fill ; read pointer == end of data -> refill

  .do_read:
  movzx rax, byte[rcx+rdi+BUFFERED_READER_BUF_OFFSET] ; Read at read pointer
  inc ecx
  mov dword[rdi+BUFFERED_READER_READ_PTR_OFFSET], ecx ; Increment read pointer
  ret

  .do_fill:
  mov r9, rdi                                   ; Struct pointer

  sub rsp, 8
  ;; Refill buffer from fd
  mov rsi, r9                        ; Struct pointer
  add rsi, BUFFERED_READER_BUF_OFFSET ; Move to start of the buffer
  mov rdi, qword[r9+BUFFERED_READER_FD_OFFSET]                      ; FD to read from
  mov rdx, READ_BUFFER_SIZE           ; Length to read
  mov rax, sys_read                   ; syscall number
  syscall
  mov rdx, rax
  add rsp, 8

  ;; If sys_read returns zero, take EOF codepath
  mov rax, BUFFERED_READER_EOF
  cmp rdx, 0
  je .eof

  ;; Set read pointer to front of buffer
  mov dword[r9+BUFFERED_READER_READ_PTR_OFFSET], 0

  ;; Set end pointer to end of valid data based upon sys_read return value
  mov dword[r9+BUFFERED_READER_END_PTR_OFFSET], edx

  xor rcx, rcx
  mov ecx, dword[r9+BUFFERED_READER_READ_PTR_OFFSET] ; Obtain read pointer
  mov rdi, r9

  jmp .do_read

  .eof:
  mov rax, BUFFERED_READER_EOF
  ret

;;; buffered_fd_reader_peek_byte(*buffered_fd_reader)
;;;   Returns the next byte without consuming it.
buffered_fd_reader_peek_byte:
  ;; Everything here copy/pasted from read_byte, just with the read pointer increment removed.
  ;; Wrapping read_byte is really slow due to function call overhead.

  ;; Decide if we need to refill the buffer
  ;;
  ;; NOTE: CPU seems to do better if we use two movs instead of use the end ptr directly in the
  ;; compare, probably because it's easier for it to realize it can load in parallel.

  mov ecx, dword[rdi+BUFFERED_READER_READ_PTR_OFFSET]
  mov eax, dword[rdi+BUFFERED_READER_END_PTR_OFFSET]
  cmp ecx, eax                                        ; Compare offsets
  je .do_fill ; read pointer == end of data -> refill

  .do_read:
  movzx rax, byte[rcx+rdi+BUFFERED_READER_BUF_OFFSET] ; Read at read pointer
  ret

  .do_fill:
  mov r9, rdi                                   ; Struct pointer

  sub rsp, 8
  ;; Refill buffer from fd
  mov rsi, r9                        ; Struct pointer
  add rsi, BUFFERED_READER_BUF_OFFSET ; Move to start of the buffer
  mov rdi, qword[r9+BUFFERED_READER_FD_OFFSET]                      ; FD to read from
  mov rdx, READ_BUFFER_SIZE           ; Length to read
  mov rax, sys_read                   ; syscall number
  syscall
  mov rdx, rax
  add rsp, 8

  ;; If sys_read returns zero, take EOF codepath
  mov rax, BUFFERED_READER_EOF
  cmp rdx, 0
  je .eof

  ;; Set read pointer to front of buffer
  mov dword[r9+BUFFERED_READER_READ_PTR_OFFSET], 0

  ;; Set end pointer to end of valid data based upon sys_read return value
  mov dword[r9+BUFFERED_READER_END_PTR_OFFSET], edx

  xor rcx, rcx
  mov ecx, dword[r9+BUFFERED_READER_READ_PTR_OFFSET] ; Obtain read pointer
  mov rdi, r9

  jmp .do_read

  .eof:
  mov rax, BUFFERED_READER_EOF
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

