;; Byte Buffer
;;   An automatically growing bag of bytes.

section .text
global byte_buffer_new
global byte_buffer_free
global byte_buffer_get_write_ptr
global byte_buffer_get_data_length
global byte_buffer_get_buf_length
global byte_buffer_get_buf
global byte_buffer_reset
global byte_buffer_push_byte
global byte_buffer_push_byte_n_times
global byte_buffer_push_int16
global byte_buffer_push_int32
global byte_buffer_push_int64
global byte_buffer_push_barray
global byte_buffer_push_barray_bytes
global byte_buffer_push_bytes
global byte_buffer_push_int_as_width_LE
global byte_buffer_push_int_as_width_BE
global byte_buffer_write_int64
global byte_buffer_pop_bytes
global byte_buffer_pop_int64
global byte_buffer_read_int64
global byte_buffer_peek_int64
global byte_buffer_dump_buffer
global byte_buffer_bindump_buffer
global byte_buffer_write_contents
global byte_buffer_delete_bytes
global byte_buffer_extend
global byte_buffer_push_byte_buffer

extern malloc
extern realloc
extern free
extern write_char
extern error_exit
extern assert_stack_aligned
extern bindump
extern write
extern write_as_base

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

%define BYTE_BUFFER_START_SIZE 128 ; Must be a power of 2

;;; byte_buffer_new()
;;;   Creates a new byte buffer
;;;
;;;   Free with byte_buffer_free when done.
byte_buffer_new:
  push r12
  push r13
  push r14

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; NOTE: we allocate the struct before the backing buffer - and free in the reverse
  ;; order to keep our bump allocator happy and fast.

  ;; Allocate struct
  mov rdi, 32
  call malloc
  mov r13, rax

  cmp r13, 0
  jne .new_struct_good_malloc

  ;; Error and exit if malloc failed
  mov rdi, malloc_failed_error_str
  mov rsi, malloc_failed_error_str_len
  call error_exit

  .new_struct_good_malloc:

  ;; Allocate backing buffer
  mov rdi, BYTE_BUFFER_START_SIZE
  call malloc
  mov r12, rax ; r12 = backing buffer

  cmp r12, 0
  jne .good_malloc

  ;; Error and exit if malloc failed
  mov rdi, malloc_failed_error_str
  mov rsi, malloc_failed_error_str_len
  call error_exit

  .good_malloc:

  ;; Initialize struct members
  mov qword [r13+BYTE_BUFFER_DATA_LENGTH_OFFSET], 0
  mov qword [r13+BYTE_BUFFER_BUF_LENGTH_OFFSET], BYTE_BUFFER_START_SIZE
  mov qword [r13+BYTE_BUFFER_BUF_OFFSET], r12
  mov rax, r13
  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_free(*byte_buffer)
;;;   Frees a byte buffer
byte_buffer_free:
  push r12
  mov r12, rdi ; Pointer to byte buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  call free

  mov rdi, r12
  call free

  pop r12
  ret

;;; byte_buffer_get_write_ptr(*byte_buffer)
;;;   Returns a byte buffer's write ptr
byte_buffer_get_write_ptr:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_OFFSET]
  add rax, qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  ret

;;; byte_buffer_get_data_length(*byte_buffer)
;;;   Returns a byte buffer's data length
byte_buffer_get_data_length:
  mov rax, qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  ret

;;; byte_buffer_reset(*byte_buffer)
;;;   Returns the byte buffer to a semantically empty state by setting the data length to zero.
;;;   Does not actually change or zero any data.
byte_buffer_reset:
 mov qword[rdi+BYTE_BUFFER_DATA_LENGTH_OFFSET], 0
 ret

;;; byte_buffer_get_buf_length(*byte_buffer)
;;;   Returns a byte buffer's buffer length
byte_buffer_get_buf_length:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_LENGTH_OFFSET]
  ret

;;; byte_buffer_get_buf(*byte_buffer)
;;;   Returns a byte buffer's backing buffer
byte_buffer_get_buf:
  mov rax, qword[rdi+BYTE_BUFFER_BUF_OFFSET]
  ret

;;; byte_buffer_write_contents(*byte_buffer, fd)
;;;   Writes the contents of this buffer to fd
byte_buffer_write_contents:
  push r12
  push r13
  sub rsp, 8

  mov r13, rdi ; byte buffer
  mov r12, rsi ; fd

  mov rdi, qword[r13+BYTE_BUFFER_BUF_OFFSET]
  mov rsi, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  mov rdx, r12
  call write

  add rsp, 8
  pop r13
  pop r12
  ret

;;; byte_buffer_write_int64(*byte_buffer, index, int64)
;;;   Writes a int64 at a specific index in the byte buffer
;;;
;;;   Index is specified in terms of bytes, not int64s.
;;;
;;;   Never changes the data length.
;;;
;;;   If the index is equal to or greater than the current data length,
;;;   invalidates any pointers pointing to within the int64 buffer.
byte_buffer_write_int64:
  push r12
  push r13
  push r14

  mov r12, rdi ; byte buffer
  mov r13, rsi ; byte index
  mov r14, rdx ; int64

  ;; Check if we need to expand the buffer
  mov rax, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; rax = ptr to raw buffer
  add rax, qword[r12+BYTE_BUFFER_BUF_LENGTH_OFFSET]
  mov rcx, r13
  add rcx, 8
  cmp rax, rcx ; cmp buf end to index+8
  jg .after_expand

  ;; Expand the buffer
  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET]         ; buffer
  mov rsi, qword[r12+BYTE_BUFFER_BUF_LENGTH_OFFSET]  ; new size = current size
  shl rsi, 1                                         ; * 2
  mov qword [r12+BYTE_BUFFER_BUF_LENGTH_OFFSET], rsi ; write new size
  call realloc

  cmp rax, 0
  jne .good_realloc

  ;; Error and exit if realloc failed
  mov rdi, realloc_failed_error_str
  mov rsi, realloc_failed_error_str_len
  call error_exit

  .good_realloc:

  mov qword[r12+BYTE_BUFFER_BUF_OFFSET], rax ; update buf ptr to realloc result

  .after_expand:

  ;; Write the byte
  mov rcx, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  mov qword[rcx+r13], r14

  pop r14
  pop r13
  pop r12
  ret

;; TODO optimize the other push_int** like below

;;; byte_buffer_push_int64(*byte_buffer, int64)
;;;   Pushes a byte to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_int64:
  push r12
  push r13
  sub rsp, 8

  mov r12, rsi ; int64
  mov r13, rdi ; Byte buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  .retry:
  ;; Work out pointer to the first unwritten byte in buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_OFFSET]
  add rsi, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]

  ;; Check if we need to expand the buffer

  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]        ; rax = ptr to byte buffer
  add rax, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET] ; rax += buf length
  mov rcx, rsi
  add rcx, 8
  cmp rax, rcx                                      ; cmp buf end to write end
  jge .good_buf_size

  ;; Expand the buffer

  mov rdi, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET]  ; new size = current size
  shl rsi, 1                                         ; * 2
  mov qword [r13+BYTE_BUFFER_BUF_LENGTH_OFFSET], rsi ; write new size
  call realloc
  cmp rax, 0
  jne .good_realloc

  ;; Error and exit if realloc failed
  mov rdi, realloc_failed_error_str
  mov rsi, realloc_failed_error_str_len
  call error_exit

  .good_realloc:

  mov qword[r13+BYTE_BUFFER_BUF_OFFSET], rax ; update buf ptr to realloc result
  jmp .retry

  .good_buf_size:
  ;; Write the new byte, increment written length
  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov qword[rax], r12                                ; write
  add qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET], 8   ; increment data length

  add rsp, 8
  pop r13
  pop r12
  ret

;;; byte_buffer_push_byte(*byte_buffer, byte)
;;;   Pushes a byte to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_byte:
  push r12
  push r13
  sub rsp, 8

  mov r12, rsi ; byte
  mov r13, rdi ; Byte buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Work out pointer to the first unwritten byte in buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_OFFSET]
  add rsi, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]

  ;; Check if we need to expand the buffer

  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]        ; rax = ptr to byte buffer
  add rax, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET] ; rax += buf length
  cmp rax, rsi                                      ; cmp buf end to write ptr
  jne .after_expand

  ;; Expand the buffer
  mov rdi, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; buffer
  mov rsi, qword[r13+BYTE_BUFFER_BUF_LENGTH_OFFSET]  ; new size = current size
  shl rsi, 1                                         ; * 2
  mov qword [r13+BYTE_BUFFER_BUF_LENGTH_OFFSET], rsi ; write new size
  call realloc
  cmp rax, 0
  jne .good_realloc

  ;; Error and exit if realloc failed
  mov rdi, realloc_failed_error_str
  mov rsi, realloc_failed_error_str_len
  call error_exit

  .good_realloc:

  mov qword[r13+BYTE_BUFFER_BUF_OFFSET], rax ; update buf ptr to realloc result

  .after_expand:
  ;; Write the new byte, increment written length
  mov rax, qword[r13+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov byte[rax], r12b                                ; write
  inc qword[r13+BYTE_BUFFER_DATA_LENGTH_OFFSET]      ; increment data length

  add rsp, 8
  pop r13
  pop r12
  ret


;;; byte_buffer_push_byte_n_times(*byte_buffer, byte, count)
;;;   Pushes a byte count times.
byte_buffer_push_byte_n_times:
  push r12
  push r13
  push r14

  mov r12, rdi ; byte buffer
  mov r13, rsi ; byte
  mov r14, rdx ; count

  cmp r14, 0
  je .epilogue

  .loop:
  mov rdi, r12
  mov rsi, r13
  call byte_buffer_push_byte
  dec r14
  cmp r14, 0
  jne .loop

  .epilogue:
  pop r14
  pop r13
  pop r12
  ret


;;; byte_buffer_extend(*byte_buffer, count)
;;;   Increases data length by count (expanding backing buffer if needed)
;;;
;;;   Invalidates any pointers pointing to within the buffer.
;;; TODO make this the only realloc path in byte buffer?
byte_buffer_extend:
  push r12
  push r13
  push r14

  mov r12, rdi ; byte buffer
  mov r13, rsi ; count

  ;; Work out pointer to the first unwritten byte in buffer + count
  mov r14, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  add r14, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET]
  add r14, r13

  ;; Check if we need to expand
  mov rax, qword[r12+BYTE_BUFFER_BUF_OFFSET]        ; rax = ptr to byte buffer
  add rax, qword[r12+BYTE_BUFFER_BUF_LENGTH_OFFSET] ; rax += buf length
  cmp rax, r14                                      ; cmp buf end to write ptr
  jg .after_expand

  ;; Expand the buffer
  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET]         ; buffer
  mov rsi, qword[r12+BYTE_BUFFER_BUF_LENGTH_OFFSET]  ; new size = current size
  mov rcx, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; minimum size
  add rcx, r13

  .compute_size:
   shl rsi, 1   ; * 2
   cmp rsi, rcx
   jle .compute_size

  mov qword [r12+BYTE_BUFFER_BUF_LENGTH_OFFSET], rsi ; write new size
  call realloc

  cmp rax, 0
  jne .good_realloc

  ;; Error and exit if realloc failed
  mov rdi, realloc_failed_error_str
  mov rsi, realloc_failed_error_str_len
  call error_exit

  .good_realloc:

  mov qword[r12+BYTE_BUFFER_BUF_OFFSET], rax ; update buf ptr to realloc result

  .after_expand:

  add qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET], r13 ; Add to data length

  pop r14
  pop r13
  pop r12
  ret

;;; TODO: if length hangs off RHS we subtract too much from data length
;;; byte_buffer_delete_bytes(*byte_buffer, index, length)
;;;   Deletes length bytes at index in the byte buffer.
byte_buffer_delete_bytes:
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
byte_buffer_read_int64:
  ;; Obtain backing buffer pointer
  mov rcx, qword[rdi+BYTE_BUFFER_BUF_OFFSET]

  ;; Obtain int64 at index
  mov rax, qword[rcx+rsi]
  ret



;;; byte_buffer_push_int16(*byte_buffer, int16)
;;;   Pushes an int16 to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_int16:
  push r12
  push r13
  push r14

  mov r14, rdi ; byte buffer
  mov r13, rsi ; int16 to write

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Write 2 zeros to make space in the buffer
  ;; TODO use extend or push_byte_n_times?
  mov r12, 2
  .write_int16_space:
    mov rdi, r14
    mov rsi, 0
    call byte_buffer_push_byte
    dec r12
    cmp r12, 0
    jne .write_int16_space

  ;; Replace the zeros with our int16
  mov rax, qword[r14+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r14+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov word[rax-2], r13w                              ; Write our int16

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_int32(*byte_buffer, int32)
;;;   Pushes an int32 to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_int32:
  push r12
  push r13
  push r14

  mov r14, rdi ; byte buffer
  mov r13, rsi ; int32 to write

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Write 4 zeros to make space in the buffer
  ;; TODO use extend or push_byte_n_times?
  mov r12, 4
  .write_int32_space:
    mov rdi, r14
    mov rsi, 0
    call byte_buffer_push_byte
    dec r12
    cmp r12, 0
    jne .write_int32_space

  ;; Replace the zeros with our int32
  mov rax, qword[r14+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
  add rax, qword[r14+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
  mov dword[rax-4], r13d                              ; Write our int32

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_int64(*byte_buffer, int64)
;;;   Pushes an int64 to the byte buffer
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
;byte_buffer_push_int64:
;  push r12
;  push r13
;  push r14
;
;  mov r14, rdi ; byte buffer
;  mov r13, rsi ; int64 to write
;
;  %ifdef ASSERT_STACK_ALIGNMENT
;  call assert_stack_aligned
;  %endif
;
;  ;; Write 8 zeros to make space in the buffer
;  ;; TODO use extend or push_byte_n_times?
;  mov r12, 8
;  .write_int64_space:
;    mov rdi, r14
;    mov rsi, 0
;    call byte_buffer_push_byte
;    dec r12
;    cmp r12, 0
;    jne .write_int64_space
;
;  ;; Replace the zeros with our int64
;  mov rax, qword[r14+BYTE_BUFFER_BUF_OFFSET]         ; backing buf
;  add rax, qword[r14+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; + existing data
;  mov qword[rax-8], r13                              ; Write our int64
;
;  pop r14
;  pop r13
;  pop r12
;  ret

;;; byte_buffer_push_barray(*byte_buffer, *barray)
;;;   Pushes a barray to the byte buffer.
;;;   Not just the bytes: includes the length.
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_barray:
  push r12
  push r13
  push r14

  mov r14, rdi ; byte buffer
  mov r13, rsi ; barray to write

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Write the length
  mov rdi, r14
  mov rsi, qword[r13]
  call byte_buffer_push_int64

  ;; Write bytes
  mov rdi, r14
  mov rsi, r13
  call byte_buffer_push_barray_bytes

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_barray_bytes(*byte_buffer, *barray)
;;;   Pushes barray bytes to the byte buffer. Doesn't include the length.
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_barray_bytes:
  sub rsp, 8

  ;mov rdi, rdi        ; byte buffer
  mov rdx, qword[rsi] ; length of barray
  add rsi, 8          ; Move past length
  mov rsi, rsi        ; *bytes
  call byte_buffer_push_bytes

  add rsp, 8
  ret

;;; byte_buffer_push_int_as_width_LE(*byte_buffer, int, width)
;;;   Pushes the integer to the byte buffer as [width] bytes.
;;;
;;;   width can be larger than the source int - we'll sign extend it.
byte_buffer_push_int_as_width_LE:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; byte buffer
  mov r13, rsi ; int
  mov r14, rdx ; width

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r15, 0
  .write_loop:
  cmp r14, 0
  je .write_loop_break

  mov rdx, r13
  mov cl, r15b
  sar rdx, cl

  mov rdi, r12
  mov rsi, rdx
  call byte_buffer_push_byte

  add r15, 8
  dec r14
  jmp .write_loop
  .write_loop_break:

  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_int_as_width_BE(*byte_buffer, int, width)
;;;   Pushes the integer to the byte buffer as [width] bytes.
;;;
;;;   width can be larger than the source int - we'll sign extend it.
byte_buffer_push_int_as_width_BE:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; byte buffer
  mov r13, rsi ; int
  mov r14, rdx ; width
  mov rbx, rdx

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r15, 0
  .stack_write_loop:
  cmp r14, 0
  je .stack_write_loop_break

  mov rdx, r13
  mov cl, r15b
  sar rdx, cl

  push rdx
  sub rsp, 8

  add r15, 8
  dec r14
  jmp .stack_write_loop
  .stack_write_loop_break:

  .push_loop:
  cmp rbx, 0
  jle .push_loop_break

  add rsp, 8
  pop rsi
  mov rdi, r12
  call byte_buffer_push_byte

  dec rbx
  jmp .push_loop
  .push_loop_break:

  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_bytes(*byte_buffer, *bytes, length)
;;;   Pushes bytes to the byte buffer.
;;;
;;;   Invalidates any pointers pointing to within the byte buffer.
byte_buffer_push_bytes:
  push r12
  push r13
  push r14

  mov r14, rdi ; byte buffer
  mov r13, rsi ; barray to write

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Write bytes
  mov r12, rdx ; length counter
  .write_loop:
    cmp r12, 0
    je .write_loop_break

    mov rdi, r14
    xor rsi, rsi
    mov sil, byte[r13]
    call byte_buffer_push_byte

    dec r12
    inc r13
    jmp .write_loop

  .write_loop_break:

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_push_byte_buffer(*byte_buffer_dest, *byte_buffer_source)
;;;   Pushes the bytes from the source byte buffer into the dest byte buffer
byte_buffer_push_byte_buffer:
  push r12
  push r13
  push r14

  mov r12, rdi ; byte buffer dest
  mov r13, rsi ; byte buffer src

  mov rdi, rsi
  call byte_buffer_get_data_length
  mov r14, rax

  mov rdi, rsi
  call byte_buffer_get_buf

  mov rdi, r12
  mov rsi, rax
  mov rdx, r14
  call byte_buffer_push_bytes

  pop r14
  pop r13
  pop r12
  ret

;;; byte_buffer_peek_int64(*byte_buffer) -> int64
;;;   Returns an int64 composed of the last 8 bytes in the buffer without
;;;   removing anything
byte_buffer_peek_int64:
  push r12
  mov r12, rdi

  mov rdi, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; Total data length
  mov rcx, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; pointer to backing buffer
  mov rax, qword[rcx+rdi-8]
  pop r12
  ret

;;; byte_buffer_pop_int64(*byte_buffer) -> int64
;;;   Pops and returns an int64 from the end of the buffer
byte_buffer_pop_int64:
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
byte_buffer_pop_bytes:
  push r12
  push r13
  push r14
  mov r12, rdi ; byte buffer
  mov r13, rsi ; byte count
  mov r14, rdx ; output buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
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
byte_buffer_dump_buffer:
  push r12
  push r13
  push r14
  push r15
  add rsp, 8

  mov r12, rdi ; byte buffer
  mov r13, rsi ; fd

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r14, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; data length
  mov r15, qword[r12+BYTE_BUFFER_BUF_OFFSET]
  .dump:
    cmp r14, 0
    je .done_dumping

    mov dil, byte[r15] ; byte
    mov rsi, r13       ; fd
    call write_char

    inc r15
    dec r14
    jmp .dump

  .done_dumping:

  sub rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; byte_buffer_bindump_buffer(*byte_buffer, fd, base)
;;   bindumps a byte buffer's backing buffer to fd with base.
byte_buffer_bindump_buffer:
  push r12
  mov r12, rdi

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rcx, rdx
  mov rdx, rsi ; fd
  mov rdi, qword[r12+BYTE_BUFFER_BUF_OFFSET] ; buffer
  mov rsi, qword[r12+BYTE_BUFFER_DATA_LENGTH_OFFSET] ; length
  call bindump
  pop r12
  ret

