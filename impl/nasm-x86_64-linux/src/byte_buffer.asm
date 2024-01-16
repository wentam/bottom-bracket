;; Byte Buffer
;;   An automatically growing bag of bytes.

section .text
global fn_byte_buffer_new
global fn_byte_buffer_free
global fn_byte_buffer_get_write_ptr
global fn_byte_buffer_get_data_length
global fn_byte_buffer_get_buf_length
global fn_byte_buffer_get_buf
global fn_byte_buffer_push_byte
global fn_byte_buffer_push_int64
global fn_byte_buffer_pop_bytes
global fn_byte_buffer_pop_int64
global fn_byte_buffer_read_int64
global fn_byte_buffer_peek_int64
global fn_byte_buffer_dump_buffer
global fn_byte_buffer_bindump_buffer
global fn_byte_buffer_write_contents
global fn_byte_buffer_delete_bytes

extern fn_malloc
extern fn_realloc
extern fn_free
extern fn_write_char
extern fn_error_exit
extern fn_assert_stack_aligned
extern fn_bindump
extern fn_write

section .rodata

malloc_failed_error_str: db "ERROR: Failed to allocate byte buffer (out of memory?)", 10
malloc_failed_error_str_len: equ $ - malloc_failed_error_str

realloc_failed_error_str: db "ERROR: Failed to reallocate byte buffer (out of memory?)", 10
realloc_failed_error_str_len: equ $ - realloc_failed_error_str

section .text

;;; struct byte_buffer {
;;;   int64_t data_length; // length of written data in the buffer
;;;   int64_t buf_length;  // length of the backing buffer
;;;   char* buf;           // pointer to variable-length backing buffer
;;; }

;;%define BYTE_BUFFER_WRITE_PTR_OFFSET 0
%define BYTE_BUFFER_DATA_LENGTH_OFFSET 0
%define BYTE_BUFFER_BUF_LENGTH_OFFSET 8
%define BYTE_BUFFER_BUF_OFFSET 16

%define BYTE_BUFFER_START_SIZE 256 ; Must be a power of 2

;;; byte_buffer_new()
;;;   Creates a new byte buffer
;;;
;;;   Free with byte_buffer_free when done.
fn_byte_buffer_new:
  push r12

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Allocate backing buffer
  mov rdi, BYTE_BUFFER_START_SIZE
  call fn_malloc
  mov r12, rax ; r12 = backing buffer

  cmp r12, 0
  jne new_buffer_good_malloc

  ;; Error and exit if malloc failed
  mov rdi, malloc_failed_error_str
  mov rsi, malloc_failed_error_str_len
  call fn_error_exit

  new_buffer_good_malloc:

  ;; Allocate struct
  mov rdi, 32
  call fn_malloc

  cmp rax, 0
  jne new_struct_good_malloc

  ;; Error and exit if malloc failed
  mov rdi, malloc_failed_error_str
  mov rsi, malloc_failed_error_str_len
  call fn_error_exit

  new_struct_good_malloc:

  ;; Initialize struct members
  mov qword [rax+BYTE_BUFFER_DATA_LENGTH_OFFSET], 0
  mov qword [rax+BYTE_BUFFER_BUF_LENGTH_OFFSET], BYTE_BUFFER_START_SIZE
  mov qword [rax+BYTE_BUFFER_BUF_OFFSET], r12

  pop r12
  ret

;;; byte_buffer_free(*byte_buffer)
;;;   Frees a byte buffer
fn_byte_buffer_free:
  push r12
  mov r12, rdi ; Pointer to byte buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  call fn_free

  mov rdi, r12
  call fn_free

  pop r12
  ret

;;; byte_buffer_get_write_ptr(*byte_buffer)
;;;   Returns a byte buffer's write ptr
fn_byte_buffer_get_write_ptr:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_OFFSET]
  add rax, qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  ret

;;; byte_buffer_get_data_length(*byte_buffer)
;;;   Returns a byte buffer's data length
fn_byte_buffer_get_data_length:
  mov rax, qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  ret

;;; byte_buffer_get_buf_length(*byte_buffer)
;;;   Returns a byte buffer's buffer length
fn_byte_buffer_get_buf_length:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_LENGTH_OFFSET]
  ret

;;; byte_buffer_get_buf(*byte_buffer)
;;;   Returns a byte buffer's backing buffer
fn_byte_buffer_get_buf:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_OFFSET]
  ret

;;; byte_buffer_write_contents(*byte_buffer, fd)
;;;   Writes the contents of this buffer to fd
fn_byte_buffer_write_contents:
  push r12
  push r13
  sub rsp, 8

  mov r13, rdi ; byte buffer
  mov r12, rsi ; fd

  mov rdi, qword[r13+BYTE_BUFFER_BUF_OFFSET]
  mov rsi, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  mov rdx, r12
  call fn_write

  add rsp, 8
  pop r13
  pop r12
  ret


;;; byte_buffer_push_byte(*byte_buffer, byte)
;;;   Pushes a byte to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
fn_byte_buffer_push_byte:
  push r12
  push r13
  sub rsp, 8

  mov r12, rsi ; byte
  mov r13, rdi ; Byte buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Work out pointer to the first unwritten byte in buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_OFFSET]
  add rsi, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]

  ;; Check if we need to expand the buffer

  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]        ; rax = ptr to byte buffer
  add rax, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET] ; rax += buf length
  cmp rax, rsi                                      ; cmp buf end to write ptr
  jne after_expand

  ;; Expand the buffer
  mov rdi, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET]  ; new size = current size
  shl rsi, 1                                         ; * 2
  mov qword [r13+BYTE_BUFFER_BUF_LENGTH_OFFSET], rsi ; write new size
  call fn_realloc

  cmp rax, 0
  jne good_realloc

  ;; Error and exit if realloc failed
  mov rdi, realloc_failed_error_str
  mov rsi, realloc_failed_error_str_len
  call fn_error_exit

  good_realloc:

  mov qword[r13+BYTE_BUFFER_BUF_OFFSET], rax ; update buf ptr to realloc result

  after_expand:
  ;; Write the new byte, increment written length
  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov byte[rax], r12b                                ; write
  inc qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]      ; increment data length

  add rsp, 8
  pop r13
  pop r12
  ret

;;; TODO: if length hangs off RHS we subtract too much from data length
;;; byte_buffer_delete_bytes(*byte_buffer, index, length)
;;;   Deletes length bytes at index in the byte buffer.
fn_byte_buffer_delete_bytes:
  mov r8, qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; r8 = data length
  mov r9, qword[rdi+BYTE_BUFFER_BUF_OFFSET]         ; r9 = buf ptr

  mov r10, rsi ; r10 = index
  add r10, rdx ; + length
  .shift:
    cmp r10, r8
    jge .shift_break ; done if index+length >= data length

    mov cl, byte[r9+r10]
    mov byte[r9+rsi], cl ; buf[index] = buf[index+length]

    inc rsi
    inc r10
    jmp .shift

  .shift_break:

  sub r8, rdx ; subtract from total data length

  ;; If that was less than zero, make it zero
  cmp r8, 0
  mov rcx, 0
  cmovl r8, rcx

  mov qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET], r8

  ret

;;; byte_buffer_read_int64(*byte_buffer, index)
;;;   Reads an int64 start at the byte specified by index
;;;
;;;   The index is not specified in terms of int64s but in terms of bytes.
fn_byte_buffer_read_int64:
  ;; Obtain backing buffer pointer
  mov rcx, qword[rdi+BYTE_BUFFER_BUF_OFFSET]

  ;; Obtain int64 at index
  mov rax, qword[rcx+rsi]
  ret


;;; byte_buffer_push_int64(*byte_buffer, int64)
;;;   Pushes an int64 to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
fn_byte_buffer_push_int64:
  push r12
  push r13
  push r14

  mov r14, rdi ; byte buffer
  mov r13, rsi ; int64 to write

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Write 8 zeros to make space in the buffer
  mov r12, 8
  write_int64_space:
  mov rdi, r14
  mov rsi, 0
  call fn_byte_buffer_push_byte
  dec r12
  cmp r12, 0
  jne write_int64_space

  ;; Replace the zeros with our int64
  mov rax, qword[r14+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r14+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov qword[rax-8], r13                              ; Write our int64

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_peek_int64(*byte_buffer) -> int64
;;;   Returns an int64 composed of the last 8 bytes in the buffer without
;;;   removing anything
fn_byte_buffer_peek_int64:
  push r12
  mov r12, rdi

  mov rdi, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; Total data length
  mov rcx, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; pointer to backing buffer
  mov rax, qword[rcx+rdi-8]
  pop r12
  ret

;;; byte_buffer_pop_int64(*byte_buffer) -> int64
;;;   Pops and returns an int64 from the end of the buffer
fn_byte_buffer_pop_int64:
  push r12
  mov r12, rdi ; byte buffer

  mov rdi, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  sub rdi, 8
  mov qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET], rdi

  mov rcx, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; pointer to backing buffer
  mov rax, qword[rcx+rdi]
  pop r12
  ret

;;; byte_buffer_pop_bytes(*byte_buffer, byte_count)
;;;   Removes byte_count bytes off the end of the buffer.
;;;
;;;   Returns a pointer to the removed segment. Writing to
;;;   the byte buffer invalidates the returned pointer (copy the data
;;;   if you need to keep it).
fn_byte_buffer_pop_bytes:
  push r12
  push r13
  push r14
  mov r12, rdi ; byte buffer
  mov r13, rsi ; byte count
  mov r14, rdx ; output buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  sub qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET], r13

  mov rax, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; buffer pointer
  add rax, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  pop r14
  pop r13
  pop r12
  ret

;;; TODO is this a duplicate of write-contents?
;;; if not, document the differences more clearly.
;;;
;;; byte_buffer_dump_buffer(*byte_buffer, fd)
;;;   Writes the contents of the buffer to fd
fn_byte_buffer_dump_buffer:
  push r12
  push r13
  push r14
  push r15
  add rsp, 8

  mov r12, rdi ; byte buffer
  mov r13, rsi ; fd

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r14, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; data length
  mov r15, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  dump:
    cmp r14, 0
    je done_dumping

    mov dil, byte[r15] ; byte
    mov rsi, r13       ; fd
    call fn_write_char

    inc r15
    dec r14
    jmp dump

  done_dumping:

  sub rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; byte_buffer_bindump_buffer(*byte_buffer, fd, base)
;;   bindumps a byte buffer's backing buffer to fd with base.
fn_byte_buffer_bindump_buffer:
  push r12
  mov r12, rdi

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rcx, rdx
  mov rdx, rsi ; fd
  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; buffer
  mov rsi, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; length
  call fn_bindump
  pop r12
  ret

