
;;;; Data structure with stack and key-value store-like propreties.
;;;;
;;;; You can look up a frame by key, and you'll get the highest frame that uses that key. Pushing
;;;; a new frame with that key masks the lower key until you pop it.
;;;;
;;;; Used for multiple things inside bottom bracket, but principally for tracking currently
;;;; active macros.

;;; * 2^16 max key length (64K)
;;; * Maximum of 2^16 (64K) entries with the same key (THIS WOULD BE A VERY WEIRD THING TO DO)
;;; * Maximum of 2^32 (~4 billion) entries. Each entry represents a user-defined macro,
;;; and I doubt any user will manage to write 4 billion macros and have them all on the stack
;;; at the same time.
;;; * Maximum of 4GB worth of keys+(6*entry_count). Practically this means probably around a maximum
;;;   of 100 million macros on the stack at a time, but it depends on key size.
;;;   * I think it's okay. chromium has probably around 200k-400k functions *total* across all TUs.
;;;     We support 100 million macros in a *single* TU. Thus completely reasonable limit.
;;;
;;; struct key {
;;;   u16 length
;;;   u8  bytes[length]
;;; }
;;;
;;; struct key_index_value {
;;;   u16 count
;;;   u32 frame_indices[count]; // In stack order. Later elements mask earlier elements.
;;; }
;;;
;;; struct frame {
;;;   u32 id;         // Negative id means this frame is dead/deleted.
;;;   u32 key_relptr; // technically optional since we'll always use the index
;;;   u64 value;
;;; }
;;;
;;; struct key_index_entry {
;;;   u32 key_relptr; // Pointer to key struct in key_index_data.
;;;   u32 value_relptr; // Pointer to key_index_value struct in key_index_data;
;;; }
;;;
;;; struct key_bucket {
;;;   u8 entry_count;
;;;   key_index_entry entries[MAX_BUCKET_SIZE] // fixed size, rehash upon overflow
;;; }
;;;
;;; struct kv_stack {
;;;   byte_buffer* frames;         // Compact and re-index everything when waste is high.
;;;   key_bucket*  key_buckets;    // malloc'd
;;;   byte_buffer* key_index_data; // key_relptr and value_relptr values point into this buffer. Compacted when waste is high.
;;;
;;;   u64 stale_frame_bytes;       // Bytes in frames that are dead/stale so we know when to compact.
;;;   u64 stale_key_index_bytes;   // To decide when to compact keys
;;;   u64 key_index_bucket_count;
;;; }
;;;
;;;

;;; Notes:
;;; * To look up by id we just scan. In current code it winds up being the top frame 100% of the
;;; time, and we just use ID for durability.

extern error_exit
extern malloc
extern free
extern byte_buffer_new
extern byte_buffer_free

section .rodata

not_pow2_err: db "ERROR: Non-power-of-2 bucket count requested for kv_stack. It must be a power of 2.",10
not_pow2_err_len: equ $ - not_pow2_err

section .text

%define MAX_BUCKET_SIZE 4 ; Maximum of 255 for this.

struc kv_stack
  .frames:                 resq 1 ; byte_buffer* - compact and re-index me when waste is high
  .key_buckets:            resq 1 ; key_bucket*  - malloc'd array of key_bucket
  .key_index_data:         resq 1 ; byte_buffer* - key/val relptrs use this. Compact when needed.

  .stale_frame_bytes:      resq 1 ; Stale byte count in frames so we know when to compact
  .stale_key_index_bytes:  resq 1 ; Stale byte count in key_index_data so we know when to compact.
  .key_index_bucket_count: resq 1 ; Quantity of buckets in key index
endstruc

struc frame
  .id:         resd 1
  .key_relptr: resd 1
  .value:      resq 1
endstruc

struc key_index_entry
  .key_relptr:   resd 1
  .value_relptr: resd 1
endstruc

struc key_bucket
  .entry_count: resb 1
  .entries:     resb (key_index_entry_size*MAX_BUCKET_SIZE)
endstruc

;; (starting_key_index_bucket_count) -> kv_stack*
;;
;; Starting bucket count must be a power of 2
kv_stack_2_new:
  push r12
  push r13
  push r14

  mov r12, rdi ;; Starting bucket count for key index

  ;; Error if starting bucket count not a power of 2
  mov rax, r12
  dec rax
  and rax, r12
  jz .is_pow2

  mov rdi, not_pow2_err
  mov rsi, not_pow2_err_len
  call error_exit

  .is_pow2:

  ;; Create top-level kv_stack allocation
  mov rdi, kv_stack_size
  call malloc
  mov r13, rax ; kv_stack*

  ;; Initialize all kv_struct values
  mov qword[r13+kv_stack.stale_frame_bytes], 0
  mov qword[r13+kv_stack.stale_key_index_bytes], 0
  mov qword[r13+kv_stack.key_index_bucket_count], r12

  ;; Create frames byte buffer
  call byte_buffer_new
  mov qword[r13+kv_stack.frames], rax

  ;; Create key_buckets allocation
  mov rax, key_bucket_size
  mul r12
  mov rdi, rax
  call malloc
  mov qword[r13+kv_stack.key_buckets], rax

  ;; Create key_index_data byte buffer
  call byte_buffer_new
  mov qword[r13+kv_stack.key_index_data], rax

  mov rax, r13
  pop r14
  pop r13
  pop r12
  ret

;; (kv_stack*)
kv_stack_2_free:
  push r12

  mov r12, rdi ; kv_stack*

  ;; NOTE: we free in reverse order to kv_stack_new to be more friendly to our allocator

  ;; Free key_index_data byte buffer
  mov rdi, qword[r13+kv_stack.key_index_data]
  call byte_buffer_free

  ;; Free key_buckets allocation
  mov rdi, qword[r13+kv_stack.key_buckets]
  call free

  ;; Free frames byte buffer
  mov rdi, qword[r13+kv_stack.frames]
  call byte_buffer_free

  ;; Free top-level struct
  mov rdi, r12
  call free

  pop r12
  ret

;; TODO kv_stack_2_push
;; TODO kv_stack_2_pop
;; TODO kv_stack_2_rm_by_id
;; TODO kv_stack_2_pop_by_key
;; TODO kv_stack_2_top -> frame*
;; TODO kv_stack_2_top_with_key -> frame*
;; TODO kv_stack_2_value_by_key
;; TODO kv_stack_2_value_by_id
;; TODO kv_stack_2_top_value

;; TODO _kv_stack_compact_key_index_data
;; TODO _kv_stack_compact_frames

%define FNV_OFFSET 14695981039346656037
%define FNV_PRIME 1099511628211

;; (barray, bucket_count) -> u64
_kv_stack_key_bucket:
  dec rsi ; we need bucket_count-1 for fake-modulo masking

  mov rax, FNV_OFFSET
  mov rcx, FNV_PRIME

  mov r8, qword[rdi]  ; barray len
  add rdi, 8          ; move past len

  .loop:
    test r8, r8
    jz .loop_break

    xor al, byte[rdi]  ; ^= byte
    mul rcx            ; *= FNV_PRIME

    inc rdi
    dec r8
    jmp .loop
  .loop_break:

  and rax, rsi       ; %= bucket_count
  ret

;; TODO compact key index data when >= 25% waste
;;   * NOTE: key relptrs exist in regular frames too, so make sure we repoint both the frames and
;;     the index relptrs upon compaction.
;; TODO compact frames whin >= 25% waste

