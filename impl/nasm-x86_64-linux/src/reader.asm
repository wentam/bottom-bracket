;;; TODO: should this move 'rsp' to a heap allocation with MAP_STACK?
;;;
;;; This is recursive and at time of writing overflows the stack at around
;;; 60k array nestings. Moving rsp into the heap during the recursive
;;; portion would increase this limit dramatically.

section .text
global read
global _read ; for reader macros
global free_read_result
global dump_read_result_buffer
global dump_read_result

;; TODO cleanup unused
extern read_char
extern malloc
extern realloc
extern free
extern write_char
extern write
extern exit
extern error_exit
extern BUFFERED_READER_EOF
extern assert_stack_aligned
extern bindump
extern write_as_base
extern rel_to_abs

extern buffered_fd_reader_new
extern buffered_fd_reader_free
extern buffered_fd_reader_read_byte
extern buffered_fd_reader_peek_byte
extern buffered_fd_reader_consume_leading_whitespace

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_push_int64
extern byte_buffer_push_byte
extern byte_buffer_dump_buffer
extern byte_buffer_get_write_ptr
extern byte_buffer_get_data_length
extern byte_buffer_get_buf
extern byte_buffer_bindump_buffer

extern macro_stack_reader

extern kv_stack_value_by_key

section .rodata
;;; Syscall numbers
sys_write: equ 0x01
sys_read:  equ 0x00
sys_exit:  equ 0x3c

stdin_fd:  equ 0
stdout_fd: equ 1
stderr_fd: equ 2

%define READ_BUFFER_SIZE 4096
%define OUTPUT_BUFFER_START_SIZE 16
%define NEWLINE 10
%define TAB 9

unexpected_eof_str: db "ERROR: Unexpected EOF while reading (did you give me any input?)",10
unexpected_eof_str_len: equ $ - unexpected_eof_str

no_macro_str: db "ERROR: Reader found no macro to handle input (Hint: you can define a reader macro called 'catchall').",10
no_macro_str_len: equ $ - no_macro_str

catchall_macro_name: db 8,0,0,0,0,0,0,0,"catchall"

section .text

;;; read(fd) -> ptr
;;;   Reads one expression from the file descriptor into internal representation
;;;
;;;   You must free the result with free_read_result when done.
;;;
;;;   Returns NULL if the read result is nothing.
read:
  push r15
  push r14
  push r13
  push r12
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r12, rdi ; We'll need this later but are about to clobber it

  ;; Create new buffered reader
  mov rdi, r12
  call buffered_fd_reader_new
  mov r13, rax ; r13 = new buffered reader

  ;; Allocate output byte buffer
  call byte_buffer_new
  mov r14, rax

  ;; TODO put _read in a loop:
  ;;        * Call _read
  ;;        * If it returns -1 and the next char is not EOF, repeat
  ;;        * Else break loop
  .rloop:

  ;; Call recursive implementation
  mov rdi, r13
  mov rsi, r14
  call _read
  mov r15, rax

  cmp rax, -1
  jne .rloop_break

  mov rdi, r13
  call buffered_fd_reader_consume_leading_whitespace
  cmp rax, BUFFERED_READER_EOF
  je .rloop_break

  jmp .rloop
  .rloop_break:

  ;; Free buffered reader
  mov rdi, r13
  call buffered_fd_reader_free

  ;; Append a pointer to the byte buffer struct at the end of the data.
  ;; This is needed to free the buffer later (and useful for any other function
  ;; that wants to go from read result back to byte buffer struct)
  mov rdi, r14
  mov rsi, 0
  call byte_buffer_push_int64

  ;; TODO: lock writes in the byte buffer so nothing can invalidate any
  ;; pointers from here forward?

  ;; Overwrite the int64 we just wrote with the actual pointer
  ;; now that it's done resizing (so we don't invalidate our own pointer by
  ;; writing)
  mov rdi, r14
  call byte_buffer_get_data_length
  mov rdi, rax

  push rdi
  push rdi
  mov rdi, r14
  call byte_buffer_get_buf
  pop rdi
  pop rdi
  mov qword[rax+rdi-8], r14


  mov rax, r15
  mov r12, rax

  cmp rax, -1
  jne .not_null
  mov rax, 0 ; We'll return NULL for this empty read result
  jmp .null

  .not_null:
  ;; r12 contains a relative pointer, we need to return absolute.
  mov rdi, r14
  call byte_buffer_get_buf
  add rax, r12

  .null:

  ;; Convert relative pointers to absolute
  push rax
  sub rsp, 8
  mov rdi, rax
  mov rsi, r14
  call rel_to_abs
  add rsp, 8
  pop rax

  add rsp, 8
  pop r12 ; Restore
  pop r13 ; Restore
  pop r14 ; Restore
  pop r15
  ret

;;; free_read_result(*read_result)
;;;   Frees all memory associated with a call to read().
free_read_result:
  sub rsp, 8
  cmp rdi, 0 ; if NULL just return
  je .done

  call _get_byte_buf_from_read_result
  mov rdi, rax
  call byte_buffer_free

  .done:
  add rsp, 8
  ret

;;; _read(*buffered_fd_reader, *output_buffer) -> ptr
;;;   Recursive implementation of read(). Return a *buffer-relative* pointer to
;;;   the result.
;;;
;;;   Returns -1 if the read result is nothing.
_read:
  push r12
  push r13
  push r14
  push r15
  push rbx
  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Consume all the leading whitespace (this also peeks)
  mov rdi, r12
  call buffered_fd_reader_consume_leading_whitespace

  ;; If we got EOF, Error
  cmp rax, BUFFERED_READER_EOF
  je .unexpected_eof

  ;; Try to call a reader macro by this char's name
  ;; TODO support multi-char reader macros
  ;; TODO if a catchall macro exists ahead of a named one, it should probably
  ;; shadow all other macros
  push rax
  mov rcx, 1
  push rcx
  mov rdi, qword[macro_stack_reader]
  mov rsi, rsp
  call kv_stack_value_by_key
  mov rdi, r12
  mov rsi, r14
  mov rbx, rax
  cmp rax, 0
  je .nullfunc
  call qword[rax+8]
  .nullfunc:

  pop rcx
  pop rcx

  cmp rbx, 0
  jne .epilogue

  ;; No direct macro matches, try for the catchall macro
  mov rdi, qword[macro_stack_reader]
  mov rsi, catchall_macro_name
  call kv_stack_value_by_key
  mov rdi, r12
  mov rsi, r14
  mov rbx, rax
  cmp rax, 0
  je .nullfunc2
  call qword[rax+8]
  .nullfunc2:

  cmp rbx, 0
  je .no_macro

  jmp .epilogue ; Return. rax is already a pointer to the barray.

  .no_macro:
  mov rdi, no_macro_str
  mov rsi, no_macro_str_len
  call error_exit

  .unexpected_eof:
  mov rdi, unexpected_eof_str
  mov rsi, unexpected_eof_str_len
  call error_exit

  .epilogue:

  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; dump_read_result_buffer(*reader_result, fd, base)
;;;   bindumps a read result's backing buffer to fd with base.
dump_read_result_buffer:
  push r12
  push r13
  sub rsp, 8

  cmp rdi, 0
  je .done

  mov r12, rsi ; fd
  mov r13, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;mov rdi, rdi
  call _get_byte_buf_from_read_result
  mov rdi, rax
  mov rsi, r12
  mov rdx, r13
  call byte_buffer_bindump_buffer

  .done:
  add rsp, 8
  pop r13
  pop r12
  ret

;; dump_read_result(*reader_result, fd, base)
;;   bindumps a read result
dump_read_result:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  cmp rdi, 0
  je .epilogue

  mov r12, rdi ; reader result
  mov r13, rsi ; fd
  mov r14, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Work out how many bytes to dump
  mov r15, 0 ; length in bytes
  mov rax, qword[r12]
  cmp rax, 0
  jl .parray_buf

  .barray_buf:
  add r15, 8 ; the length itself
  add r15, rax ; each char is one byte, so just add it
  jmp .length_calculated

  .parray_buf:
  not rax ; parray lengths are negative one's complement, make it positive
  add r15, 8 ; the length itself
  imul rax, 8
  add r15, rax
  ;jmp .length_calculated

  .length_calculated:

  mov rdi, r12
  mov rsi, r15
  mov rdx, r13
  mov rcx, r14
  call bindump

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret


;;; _get_byte_buf_from_read_result(*reader_result) -> *byte_buffer
;;;   Given a result turned by read(), returns a pointer to it's original
;;;   backing buffer.
_get_byte_buf_from_read_result:
  push r12
  mov r12, rdi ; reader result

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rax, qword[r12]
  cmp rax, 0
  jl .parray_buf

  .barray_buf:
  add r12, 8   ; move past the length
  mov rax, qword[r12+rax]
  jmp .epilogue

  .parray_buf:
  not rax ; parray lengths are negative one's complement, invert
  add r12, 8 ; move past the length
  imul rax, 8
  mov rax, qword[r12+rax]
  ;jmp .epilogue


  .epilogue:
  pop r12
  ret
