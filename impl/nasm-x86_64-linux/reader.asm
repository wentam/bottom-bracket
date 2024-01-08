section .text
global fn_read
extern fn_read_char
extern fn_malloc
extern fn_realloc
extern fn_free
extern fn_write_char
extern fn_print
extern fn_exit
extern fn_error_exit
extern BUFFERED_READER_EOF


extern fn_buffered_reader_new
extern fn_buffered_reader_free
extern fn_buffered_reader_read_byte
extern fn_buffered_reader_peek_byte
extern fn_buffered_reader_consume_leading_whitespace

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
%define EOF 256 ;; TODO remove after factoring out buffered reader
%define NEWLINE 10
%define TAB 9

unexpected_eof_str: db "ERROR: Unexpected EOF while reading (did you give me any input?)",10
unexpected_eof_str_len: equ $ - unexpected_eof_str

unexpected_paren_str: db "ERROR: Unexpected ')' while reading",10
unexpected_paren_str_len: equ $ - unexpected_paren_str

unexpected_eof_array_str: db "ERROR: Unexpected EOF while reading array (are your parenthesis mismatched?)",10
unexpected_eof_array_str_len: equ $ - unexpected_eof_array_str

unexpected_eof_atom_str: db "ERROR: Unexpected EOF while reading atom",10
unexpected_eof_atom_str_len: equ $ - unexpected_eof_atom_str

section .text

;;; Structs:
;;;
;;; read_buffer {
;;;   char* read_ptr;              // Pointer to next byte to read
;;;   char* end_ptr;               // Pointer to end of valid data in buffer
;;;                                // (points to the first invalid byte)
;;;   char  buf[READ_BUFFER_SIZE]; // Buffer (flat in struct, not pointer)
;;; }
;;;
;;; output_buffer {
;;;   char*   write_ptr; // pointer to the next place to write
;;;   int64_t buflen;    // current length of the buffer. Must be power of 2
;;;   char buf[];        // Variable length, must be power of 2
;;;                      // (flat in struct, not pointer)
;;; }

;;; read(fd) -> ptr
;;;   Reads one expression from the file descriptor into internal representation
;;;
;;;   Caller owns the memory and must free it when done. TODO: provide function for this
fn_read:
  push r14 ; Preserve
  push r13 ; Preserve
  push r12 ; Preserve

  mov r12, rdi ; We'll need this later but are about to clobber it

  ;; Create new buffered reader
  mov rdi, r12
  call fn_buffered_reader_new
  mov r13, rax ; r13 = new buffered reader

  ;; Allocate output buffer
  mov rdi, (OUTPUT_BUFFER_START_SIZE + 16)
  call fn_malloc
  ;; TODO: check for malloc NULL, error
  mov r14, rax
  mov rdi, rax
  add rdi, 16
  mov qword [r14], rdi                        ; initialize write ptr
  mov qword [r14+8], OUTPUT_BUFFER_START_SIZE ; initialize length

  ;; Call recursive implementation
  mov rdi, r13
  mov rsi, r14
  call fn__read

  ;; Free buffered reader
  push rax
  mov rdi, r13
  call fn_buffered_reader_free
  pop rax

  ;; TODO TMP dump the output buffer
  ;; TODO debug func that does this?
  mov r13, qword[r14+8] ; Grab buffer len
  add r14, 16           ; Bump buffer pointer to actual buffer
  dump:
    cmp r13, 0
    je breakdump

    mov dil, byte[r14]
    mov rsi, stdout_fd
    call fn_write_char

    inc r14

    dec r13
    jmp dump

  breakdump:

  pop r12 ; Restore
  pop r13 ; Restore
  pop r14 ; Restore
  ret

;;; _read(*buffered_reader, *output_buffer) -> ptr
;;;   Recursive implementation of read()
fn__read:
  push r12
  push r13
  push r14
  push r15
  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume all the leading whitespace (this also peeks)
  mov rdi, r12
  call fn_buffered_reader_consume_leading_whitespace

  ;; If we got EOF, Error
  cmp rax, EOF
  je __read_unexpected_eof

  ;; If we got an array end, error
  cmp rax, ')'
  je __read_unexpected_closing_paren

  ;; Prepare arguments for _read_array/_read_atom
  mov rdi, r12
  mov rsi, r14

  ;; If it looks like an array take array codepath, else atom codepath
  cmp rax, '('
  je __read_array

  __read_atom:
  call fn__read_atom
  jmp __read_epilogue ; Return. rax is already a pointer to the atom.

  __read_array:
  call fn__read_array
  jmp __read_epilogue ; Return; rax is already a pointer to the array

  __read_unexpected_eof:
  mov rdi, unexpected_eof_str
  mov rsi, unexpected_eof_str_len
  call fn_error_exit

  __read_unexpected_closing_paren:
  mov rdi, unexpected_paren_str
  mov rsi, unexpected_paren_str_len
  call fn_error_exit

  __read_epilogue:
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _read_array(*buffered_reader, *output_buffer) -> ptr
;;;   Reads an array from the buffered reader
;;;   Writes the array to the output buffer
;;;
;;;   The first character in the buffer must be '(' TODO: assert?
;;;
;;;   Returns a pointer to the array.
fn__read_array:
  push r12
  push r14
  push r15
  push rbx

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume the leading '(' TODO assert that it is actually (
  mov rdi, r12
  call fn_buffered_reader_read_byte

  mov r15, 0 ; child counter
  __read_array_children:
  ;; Consume all whitespace
  mov rdi, r12
  call fn_buffered_reader_consume_leading_whitespace

  ;; Peek the next char (consume whitespace also peeks). If it's ')' we're done.
  cmp rax, ')'
  je __read_array_done

  ;; Error if it's EOF here
  cmp rax, EOF
  jne __read_array_no_eof

  mov rdi, unexpected_eof_array_str
  mov rsi, unexpected_eof_array_str_len
  call fn_error_exit

  __read_array_no_eof:

  ;; Read a child
  mov rdi, r12
  mov rsi, r14
  call fn__read

  ;; Push a pointer to this child onto the stack
  push rax

  inc r15 ; increment child counter

  jmp __read_array_children ; Next child

  __read_array_done:

  ;; Consume the trailing ')'
  mov rdi, r12
  call fn_buffered_reader_read_byte

  ;; Zero rbx to start tracking array size in bytes
  xor rbx, rbx

  ;; Write the array length
  mov rdi, r15
  mov rsi, r14
  call fn_write_int64_to_output_buffer

  add rbx, 8 ; 8 bytes for array length

  ;; Output array pointers
  _output_array:
  cmp r15, 0
  je _output_array_break
  pop rdi
  mov rsi, r14
  call fn_write_int64_to_output_buffer

  add rbx, 8 ; 8 bytes for pointer

  dec r15
  jmp _output_array

  _output_array_break:

  ;; Set rax to the start of the array
  mov rax, qword[r14]
  sub rax, rbx

  pop rbx
  pop r15
  pop r14
  pop r12
  ret

;;; _read_atom(*buffered_reader, *output_buffer) -> ptr
;;;   Reads an atom from the buffered reader.
;;;   Writes the atom to the output buffer.
;;;
;;;   Returns a pointer to the atom.
fn__read_atom:
  push r12
  push r14
  push r15
  push rbx

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume all the leading whitespace
  mov rdi, r12
  call fn_buffered_reader_consume_leading_whitespace

  cmp rax, EOF
  jne __read_atom_no_eof

  mov rdi, unexpected_eof_atom_str
  mov rsi, unexpected_eof_atom_str_len
  call fn_error_exit

  __read_atom_no_eof:

  ;; Write length placeholder
  mov rdi, 0
  mov rsi, r14
  call fn_write_int64_to_output_buffer

  ;; Read characters until the end of the atom
  mov rbx, 0 ;; char counter
  __read_atom_char:
  ;; Peek the next char - if it's '(', ')' or whitespace, we're done.
  ;; We cannot consume because consuming '(' or ')' would be damaging.
  mov rdi, r12 ; buffered reader
  call fn_buffered_reader_peek_byte
  cmp rax, ')'
  je __read_atom_finish
  cmp rax, '('
  je __read_atom_finish
  cmp rax, ' '
  je __read_atom_finish
  cmp rax, EOF
  je __read_atom_finish
  cmp rax, NEWLINE
  je __read_atom_finish
  cmp rax, TAB
  je __read_atom_finish

  ;; Read the next char
  mov rdi, r12
  call fn_buffered_reader_read_byte
  mov r15, rax

  ;; Output this char to the buffer
  mov rdi, r15
  mov rsi, r14
  call fn_write_to_output_buffer

  inc rbx

  ;; Repeat
  jmp __read_atom_char

  __read_atom_finish:
  ;; Update atom length placeholder
  mov rax, qword[r14]   ; Get write pointer
  sub rax, rbx          ; Subtract whatever we just wrote
  sub rax, 8            ; Subtract our placeholder length
  not rbx               ; Negate rbx as atoms should use -length
  inc rbx               ; ^^^^^^^^
  mov qword[rax], rbx ; Write our length
  ; rax should now contain a pointer to the start of our data, return

  pop rbx
  pop r15
  pop r14
  pop r12
  ret

;;; write_int64_to_output_buffer(int64, *output_buffer)
;;;   Writes an int64 to the output buffer
fn_write_int64_to_output_buffer:
  push r12
  push r13
  push r14
  mov r13, rdi ; int64 to write
  mov r14, rsi ; output buffer

  ;; Make the space with zero bytes
  mov r12, 8
  __write_int64_space:
  mov rdi, 0
  mov rsi, r14
  call fn_write_to_output_buffer
  dec r12
  cmp r12, 0
  jne __write_int64_space

  ;; Write to the space
  mov rax, qword[r14] ; Get write pointer
  mov qword[rax-8], r13

  pop r14
  pop r13
  pop r12
  ret

;;; write_to_output_buffer(byte,*output_buffer)
;;;   Writes a byte to the output buffer
fn_write_to_output_buffer:
  push r12     ; Preserve
  push r13     ; Preserve
  mov r12, rdi ; Preserve rdi (byte)
  mov r13, rsi ; Preserve rsi (output buffer)

  ;; Check if we need to expand the buffer
  mov rax, r13           ; rax  = start of struct
  add rax, qword [r13+8] ; rax += length of buffer
  add rax, 16            ; rax += struct overhead
  cmp rax, qword [r13]   ; Compare end of struct to write pointer
  jne after_expand       ; Skip expand if we haven't reached length

  ;; Expand the buffer
  mov rdi, r13           ; Output buffer struct
  mov rsi, qword [r13+8] ; New size = length of old buffer (for now)
  shl rsi, 1             ; * 2
  mov qword[r13+8], rsi  ; Write the new size to struct
  add rsi, 16            ; + struct overhead
  call fn_realloc        ; Reallocate
  ;; TODO: check for NULL and error if realloc fails

  after_expand:
  ;; Write the new byte
  mov rax, qword[r13] ; Grab write pointer
  mov qword[rax], r12 ; Write our byte at the write pointer
  inc qword[r13]      ; Increment write pointer

  pop r13 ; Restore
  pop r12 ; Restore
  ret
