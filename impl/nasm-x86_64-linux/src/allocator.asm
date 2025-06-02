;;; Bump allocator
;;;
;;; The memory allocation patterns inside bb align perfectly for the fastest
;;; type of allocator: a bump allocator. This is that.
;;;
;;; This attribute really helps mitigate the fact that recursive macroexpansion
;;; lends itself to a lot of tiny memory allocations. It's a lot of tiny allocations,
;;; but the access pattern also means we can use a simple, really fast allocator.

;;; struct chunk {
;;;   u64 refcount; // Number of allocations in the chunk. We free at zero.
;;;   char data[CHUNK_SIZE-8];
;;; }

;;; struct allocation {
;;;   void* chunk_ptr; // NULL if syscall
;;;   u64 length;      // length of allocation (the whole struct)
;;;   char data[size]; // Pointer to this is what's actually returned to the user
;;; }

%define CHUNK_REFCOUNT_OFFSET 0
%define CHUNK_DATA_OFFSET 8

%define ALLOCATION_CHUNK_PTR_OFFSET 0
%define ALLOCATION_LENGTH_OFFSET 8
%define ALLOCATION_DATA_OFFSET 16

;;; When choosing a chunk size for the bump allocator, do consider that the linux kernel
;;; allocates pages 'lazily' - it doesn't actually claim the memory until we touch the memory.
;;;
;;; That means the chunk size is not a minimum overhead, and in fact we may use far less memory.
;;;
;;; However, at the time of this writing, we only ever 'free' data by freeing entire chunks.
;;; We don't decrement the bump pointer (TODO try this and see if it's fast!). This does
;;; mean we'll use more memory with larger chunks because we never free anything.
;;;
;;; So we still need to be reasonable
%define CHUNK_SIZE (4*1024*1024)
%define SYSCALL_SPILL_SIZE 512*1024 ;; Allocations larger than this will syscall

%define MAP_ANONYMOUS  0x20
%define MAP_PRIVATE    0x02
%define PROT_READ      0x1
%define PROT_WRITE     0x2
%define PROT_EXEC      0x4
%define MREMAP_MAYMOVE 0x1

%define SYS_MMAP 9
%define SYS_MUNMAP 11
%define SYS_MREMAP 25

section .bss

current_chunk_ptr: resb 8 ; Pointer to current chunk
bump_ptr: resb 8          ; Pointer to first available byte in chunk

section .text

global malloc
global malloc_cleanup
global realloc
global free


;;; Cleans up last bump alloc chunk if it's around.
malloc_cleanup:
 mov rdi, qword[bump_ptr]
 cmp rdi, 0
 je .nope

 mov rdi, qword[current_chunk_ptr]
 mov rsi, CHUNK_SIZE
 mov rax, SYS_MUNMAP
 syscall
 ret
 .nope:
 ret

;;; TODO don't always allocate as exec. Maybe make a separate malloc_exec function call.

;;; malloc(size) -> ptr
;;;  Allocates memory. returns 0/NULL if allocation fails.
malloc:
 sub rsp, 8 ; align stack

 cmp rdi, 0
 jg .not_zero
 mov rax, 0
 add rsp, 8
 ret
 .not_zero:

 ;; If allocation is > spill size, just take slow path
 cmp rdi, SYSCALL_SPILL_SIZE
 jl .bump_alloc

 mov rsi, rdi
 add rsi, ALLOCATION_DATA_OFFSET
 mov rdi, 0 ; addr (NULL)
 mov rdx, (PROT_READ | PROT_WRITE | PROT_EXEC) ; protection flags
 mov r10, (MAP_PRIVATE | MAP_ANONYMOUS) ; flags
 mov r8,  -1       ; fd. -1 for portability with MAP_ANONYMOUS
 mov r9,  0        ; offset
 mov rax, SYS_MMAP ; syscall number
 syscall

 ;; If mmap gives us an error, take failed path
 test rax, rax
 js .failed

 ;; Write our metadata - NULL for chunk ptr, length of allocation
 mov qword[rax+ALLOCATION_CHUNK_PTR_OFFSET], 0
 mov qword[rax+ALLOCATION_LENGTH_OFFSET], rsi

 add rax, ALLOCATION_DATA_OFFSET ; Return data pointer (squirrel away our metadata)

 add rsp, 8
 ret

 .bump_alloc:
  ;; If bump_ptr is NULL, allocate a new chunk
  cmp qword[bump_ptr], 0
  je .new_chunk

  ;; If (bump_ptr+allocation+overhead)-current_chunk > chunk size, allocate a new chunk
  mov rsi, qword[bump_ptr]
  add rsi, rdi
  add rsi, ALLOCATION_DATA_OFFSET
  sub rsi, qword[current_chunk_ptr]
  cmp rsi, CHUNK_SIZE
  jge .new_chunk

  jmp .chunk_ready

  .new_chunk:
   ;; Allocate a new chunk

   push rdi ; preserve allocation length
   sub rsp, 8

   mov rdi, 0
   mov rsi, CHUNK_SIZE
   mov rdx, (PROT_READ | PROT_WRITE | PROT_EXEC) ; protection flags
   mov r10, (MAP_PRIVATE | MAP_ANONYMOUS) ; flags
   mov r8,  -1       ; fd. -1 for portability with MAP_ANONYMOUS
   mov r9,  0        ; offset
   mov rax, SYS_MMAP ; syscall number
   syscall

   ;; If mmap gives us an error, take failed path
   test rax, rax
   js .failed

   ;; Update our global pointers

   mov qword[current_chunk_ptr], rax
   mov qword[bump_ptr], rax
   add qword[bump_ptr], CHUNK_DATA_OFFSET

   mov qword[rax+CHUNK_REFCOUNT_OFFSET], 0 ; zero out refcount

   add rsp, 8
   pop rdi

  .chunk_ready:
   mov rcx, qword[bump_ptr]

   ;; Write our metadata
   mov rdx, qword[current_chunk_ptr]
   mov qword[rcx + ALLOCATION_CHUNK_PTR_OFFSET], rdx
   mov qword[rcx + ALLOCATION_LENGTH_OFFSET], rdi

   ;; Set up our return value
   mov rax, rcx
   add rax, ALLOCATION_DATA_OFFSET

   ;; Increment and align bump pointer by our allocation struct size (rdi+overhead)
   mov rsi, rdi
   add rsi, ALLOCATION_DATA_OFFSET
   add rsi, rcx
   add rsi, 15  ; 16-align the pointer
   and rsi, -16 ; ^^^^
   mov qword[bump_ptr], rsi

   ;; Increment refcount
   mov rdi, qword[current_chunk_ptr]
   inc qword[rdi + CHUNK_REFCOUNT_OFFSET]

   add rsp, 8
   ret

 .failed:
 mov rax, 0
 add rsp, 8
 ret

;;; realloc(ptr, new_size) -> ptr
realloc:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi
  mov r13, rsi

  ;; NULL ptr -> just return
  test r12, r12
  jz .epilogue

  ;; Realloc to size 0 -> just free
  test r13, r13
  jnz .not_zero

  call free
  jmp .epilogue

  .not_zero:

  sub r12, ALLOCATION_DATA_OFFSET ; Walk back to our full allocation struct

  mov rdx, qword[r12 + ALLOCATION_CHUNK_PTR_OFFSET]
  mov r15, qword[r12 + ALLOCATION_LENGTH_OFFSET]

  cmp rdx, 0
  je .is_syscall_alloc

  .is_bump_alloc:

  ;; For simplicity's sake, we just call malloc again and free the old result.
  ;; TODO optimization: if we were this last allocation in this chunk and there's enough room,
  ;; we could grow in-place
  ;; TODO optimization: if we're shrinking, we can always shrink in place

  mov rdi, r13
  call malloc
  mov r14, rax
  test rax, rax
  jz .failed

  ;; Clamp copy length to new size
  mov rcx, r15
  cmp rcx, r13
  cmova rcx, r13

  ;; Copy data to new allocation
  mov rdi, r14 ; dest
  mov rsi, r12 ; src
  add rsi, ALLOCATION_DATA_OFFSET
  cld
  rep movsb

  mov rdi, r12
  add rdi, ALLOCATION_DATA_OFFSET
  call free

  mov rax, r14
  jmp .epilogue
  .is_syscall_alloc:

  mov rdi, r12 ; old address
  mov rsi, r15 ; old size
  mov rdx, r13 ; new size
  add rdx, ALLOCATION_DATA_OFFSET
  mov r10, MREMAP_MAYMOVE
  mov r8, 0 ; new address (unused with current flags)
  mov rax, SYS_MREMAP
  syscall

  test rax, rax
  js .failed

  ;; Update our length metadata
  mov qword[rax+ALLOCATION_LENGTH_OFFSET], rdx

  add rax, ALLOCATION_DATA_OFFSET

  jmp .epilogue
  .failed:
  mov rax, 0

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; free(ptr) -> int
;;;   Frees memory allocated with malloc. Returns 0 on success, -errno on error.
free:
  sub rsp, 8

  ;; Just return 0 if the user passes us a NULL ptr
  test rdi, rdi
  jz .bump_done

  sub rdi, ALLOCATION_DATA_OFFSET ; Walk back to our full allocation struct

  ;; Branch on syscall vs bump allocation
  mov rsi, qword[rdi+ALLOCATION_CHUNK_PTR_OFFSET]
  cmp rsi, 0
  je .is_syscall_allocation

  .is_bump_allocation:
   ;;; Decrement (and retain) refcount
   mov rcx, qword[rsi+CHUNK_REFCOUNT_OFFSET]
   dec rcx
   mov qword[rsi+CHUNK_REFCOUNT_OFFSET], rcx

   ;; If ref count is now zero and it's not the current chunk, free the chunk
   cmp rsi, qword[current_chunk_ptr]
   je .bump_done

   test rcx, rcx
   jnz .bump_done

   mov rdi, rsi
   mov rsi, CHUNK_SIZE
   mov rax, SYS_MUNMAP
   syscall

  .bump_done:
   mov rax, 0
   add rsp, 8
   ret

  .is_syscall_allocation:
   mov rsi, qword[rdi+ALLOCATION_LENGTH_OFFSET]
   mov rax, SYS_MUNMAP
   syscall

   add rsp, 8
   ret
