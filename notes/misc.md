Keep these notes around even after stuff is implemented so I can remember why I did things! I often forget.

Try to re-read this occassionaly when working on aarrp so we remember important things.

When reading these notes, note that the macro stack was renamed to kv stack later on, and many of these notes predate this change.


Aarrp: What if we did not inherit our abstractions, but derived them?

"first-principles reductionist simulator"

* We need structural macros like (with-popped-printer-macros (barray) (my-form)) that expand (my-form) without
specific printer macros present
* There should be no command line arguments to the aarrp binary whatsoever to avoid the platform-dependent and implementation-dependent nature of that, and the fact that we want everything to be standardized. See some of the points below on how this can be avoided. Also see tag [A] in this file.
* important: aarrp ALWAYS only evaluates one form from the input, there is no implicit top-level list or anything like that. aarrp will provide a way to wrap the input in some top-level form, so if you want you can wrap in a list or in a macro entering your language of choice. See point below about how to wrap without command line arguments in a really flexible way.
* If something doesn't need to be a builtin macro, IT SHOULD NOT BE. We want the core to be as minimal as humanly possible. We also want fewer builtins that language builders have in their namespace.
* To wrap your input in something, just use (include "file.aarrp") in your input to aarrp to template it. Example: echo '(with-popped-printer-macros (include "my-real-code.aarrp")) | aarrp'. This might be most ergonomic if 'include' is a builtin macro, though think about if there's a good way to avoid this.
* [A] If you want to define a "compile-time variable" like -D to define something, do that by wrapping at CLI time like above with a macro (not builtin) that defines them. echo '(with-macros (include "my-language.aarrp") (with-my-language (with-defined (LINUX X11 WAYLAND) (include "my-code.aarrp"))))' | aarrp. This approach is more flexible as the "CLI" arguments that are supported are not hardcoded into aarrp, and the arguments aren't implementation-defined.
* It would be cool to have the ability to "watch" macroexpansion happen step-by-step where pressing spacebar or whatever advances one expansion. This should not be done with a CLI argument, but a macro that implements this behavior printing as it goes (macros can have side-effects!)
* Should macros pushed with push-macro automatically pop at the end of the "scope"? Right now the behavior is a little bit confusing, as something very nested could push a macro that is then applied to something at the top-level. I also don't want to force the user to be so intricitally aware of macroexpansion order or make exact macroexpansion order incredibly important in the implementation.
  Perhaps what we want instead is a (with-macros) macro. Could also support both, document the caveats of (push-macro) clearly. Though once you have one, you could implement the other inside the language.
* Or maybe only have push-macro without pop-macro? It would just be the 'global' version, and we would basically have defmacro and macrolet both in the base language.
* We probably need a builtin macro that expands into the platform of the aarrp binary, such that for macros your language macro knows what type of machine code to expand into. Maybe: (aarrp-platform) expands into "x86_64-linux" (aarrp-cpu) expands into "x86_64"
* (push-macro) could accept multiple strings and concatenate the machine code for you: (push-macro my-macro "\xFF\xFF" "\xFF\xFF"). This way you could write machine code line-by-line with comments easily. Much more importantly, you could inject stuff in the middle with macros: "\xFF\xFF" (builtin-function-addr) "\xFF\xFF".
* Possibly better alternative to the above: a builtin concatenate macro (cat "str1" "str2")
* Builtin macros without some kind of intervention would exist in the user's new programming language's "namespace". Thus, we might want to at the very least provide a mechanism, such as a macro that expands into this, to discover the list of builtin macros.
  We also might not need this tho, because macros are expanded outside to inside and thus we aren't forcing anything upon them. Consider though that we might be in a part of the language that allows the user to arbitrarily expand macros, and we might want to control this list. We also might just want a (without-builtins (foo)) wrapper macro provided.
* Another idea: namespace all builtin macros as (__builtin__foo).
* note that macroexpansion does require recursion or other tree-like implementation because ((macro-1) ((foo) (macro-2 (macro-3)))) is a tree and macros need to expand. Another example: ((((macro-1)))) - macro should still expand
* I want to leave exact macroexpansion order up to the implementations so long as it's outside-in to keep the possibility of faster algorithm for expansion around.
* Perhaps the assembler really does need to be implemented in machine language, and the language itself should be exclusively machine language. This would call for a rename to "arrp" for just "array processing". This sounds like a little bit of a more "pure" concept.
* or rename to "arrap"? because lisp sounds like list and only does last letter?
* Instead of having two builtin barray printer macros, you could just have one that does it with byte strings when needed, but the user can push one that does literal barrays when needed. This could be made more ergonomic by including a (with-literal-barray-bytes foo) builtin macro.
* we need a way to specify compile-time functions that macros can call.
* a builtin (or not builtin) (with) macro that prefixes children with 'with' so you can drop into a bunch of libraries etc at once: (with (my-language (somelibrary foo) defined) my-code) expands into (with-my-language (with-some-library foo (with-defined my-code)))
  It's a bit easier to make the case for this being a builtin macro because it relates directly to the task of macro work, and helps people be comfortable with with-thing wrappers that can be resisted by some users. It's also a simple macro to implement.
* Typical programming language compilation command example: $ echo '(with-macros (include "my-language.aarrp") (with-my-language (with-defined ((OS LINUX) X11 WAYLAND) (include "my-code.aarrp"))))' | aarrp
                                  Or with the 'with' macro: $ echo '(with ((macros-from "my-language.aarrp")
                                                                           my-language
                                                                           (defined ((OS LINUX) X11 WAYLAND)))
                                                                      (include "my-code.aarrp"))' | aarrp
* Or maybe just have a 'nest' macro:
  (nest (with-macros (include "my-language.aarrp"))
        (with-my-language)
        (with-defined (stuff))
        (include "my-code.aarrp"))

  Expands into:
    (with-macros (include "my-language.aarrp")
      (with-my-language
        (with-defined (stuff)
          (include "my-code.aarrp"))))

  This solves the problem more generally.

* You could also argue that not using a 'nest' macro and just using a different indentation style solves the problem nicely:
    (with-macros (include "my-language.aarrp")
    (with-my-language
    (with-my-library
    (with-defined (stuff)
      my-code))))

This feels a little bit wrong, but so does spending build compute time on a 'nest' macro that really just changes how you indent it.

* in my higher-level language, probably call (let) (with-vars) instead to stay consistent with the 'with' pattern.
* When we say (with-macros (include "foo.aarrp") (with-macros (include "bar.aarrp") my-code)), the macros from foo.aarrp would be available inside bar.aarrp. This isn't *that* wierd, as it behaves the same way in C with #include, but we might want to provide a mechanism that locally reverts to just builtin macros, like (with-only-builtins foo). with-macros - or another macro with a similar name, could automatically use with-only-builtins.
* Note that you could build an interpreted language in aarrp by using macros for their side effects instead of what they expand into. Could implement python inside aarrp like this.
* It's definitely worth documenting clearly that macros are about both expansion *and* side-effects, unlike in CL
* Because macros are about side-effects, there's definitely an argument to be had that maybe macroexpansion needs a specified, deterministic order
* A naming scheme that differentiates between a build-time thing and a runtime thing would probably be helpful, like (push-function) and (runtime-function)
* include probably needs to be a builtin macro. Yes, you could implement it in aarrp, but there would be no way to include the include macro as a library.
* idea: markup language like markdown/latex implemented via aarrp macros (expands into some renderable format?)
* should aarrp understand that there are different platforms for machine code? When defining a macro, you could define ((x86_64 "machine_code") (risc-v "machine_code")) to support different platforms for macro execution. This could also be left up to the user to resolve by having the user access an (aarrp-platform) macro and switching themselves. This may make sense to occur in aarrp though, because aarrp's core functionality has to do with the execution of machine code. Building this into aarrp would avoid undefined behavior if you accidentally choose to execute machine code from one platform on another, and building this into aarrp would be very very simple (the x86_64 implementation of aarrp just needs to always look up the x86_64 machine code.)

(with-macros
  ((my-new-macro
     (x86_64-linux (cat
                     "some machine code" ; mov rdi, 5
                     "some machine code" ; syscall
                     "some machine code"))
     (aarch64-win32 "some ARM win32 machine code")))
   (nest
     (x86_64-linux (cat "foo" "bar"))
     (aarch64-windows (cat "foo" "bar"))))

  (elf64_relocatable foo))

Currently strongly leaning towards resolving it within aarrp. Avoids undefined behavior, can easily emit a warning if you define a macro without an implementation for the aarrp execution platform, can easily emit an error when you try to call a macro when there isn't an implementation for the aarrp execution platform, more ergonomic, doesn't really add complexity to aarrp (but would be a bit complex to do it inside the aarrp language), completely thetical to aarrp's role as managing the execution of machine-language macros. Implementing this yourself inside the aarrp language would *not* allow you to produce a nice error upon macroexpansion, so I think this is a must.

Question is: is this by cpu arch? x86_64, arm? or By platform: x86_64-linux, arm-windows. My current intuition says platform: I think you want a separate entry to occur per implementation required - which itself is a good way to define "platform" within aarrp. Windows and linux have different "system" apis, linux with syscalls and windows with win32, and this demands separate implementations.

This does result in a combinatorial explosion of assemblers required to be implemented in machine language inside the aarrp language, but I think that's just reality.

Note: to avoid actually running an assembler/compiler for all supported platforms when defining a macro, you could have your IR assembler/compiler accept an instruction to only produce a specified platform - then pass it (aarrp-platform).

Another interesting thing to note is that this would allow aarrp implementations to do some weird stuff like support execution of macros written for another platform through virtualization. This is actually a good argument to NOT have your IR assembler expand into only one but always provide all options. This is actually really interesting because it doesn't actually assume what our host platform is, we're just listing the ways we know how to accomplish the task and letting the aarrp implementation choose whichever it knows how to execute best. It's also probably not that big of a deal to have your high-level language expand into all, because this portability is implemented at the IR level which should be a case of quick assembly for all.

If needing to assemble and optimize the IR 20 times is too expensive, aarrp implementations could also provide a list of the macro execution platforms it supports sorted by priority, and the IR could limit it's expansions. Probably also providing stubs for other supported platforms so you can still see a list of supported platforms inside aarrp.

Another perspective: this is actually a little bit weird, because you only ever need one platform at a given time. (with-macros) could also always only accept the correct machine code for the aarrp execution platform, and you could also provide a (select-platform) macro that expands into the relevant platform for convenience:

(with-macros
  ((elf64-relocatable
     (select-platform
       (x86_64-linux   "machine code")
       (risc-v-windows "machine code")))))

The downside of this is the inability to have nice errors if you try to execute a macro on an unsupported platform.

* Due to the above, we could support a lot of platforms easily by for example using box64 in an ARM implementation of aarrp to support macroexpansion.

* To bootstrap aarrp, we could implement it once in as simple of an assembly language as possible - like RISC-V - then demand that those who wish to bootstrap must run a RISC-V virtual machine. If you keep it to a minimal portion of the risc-V instruction set, said VM could be very simple. We could even write some VMs.
* Idea: support execution of macros written for a different platform/arch through virtualization in more advanced implementations of aarrp.
* Helpful line for documentation purposes: "aarrp exposes all levels of abstraction for you to see and interact with, including machine language."
* Once we have a high-level language, a video walking through the abstractions bottom-up would be a great way to demonstrate what aarrp is about.
* We probably want to implement macros in the aarrp language (not builtin) for elf executables (not just relocatable object files), as well as implement a linker directly in macros. That way, you can actually specify your entire build process directly inside aarrp.

(link-elf-executable (elf64-relocatable foo) (include "somefile_with_elf64-relocatable.aarrp"))

Would expand into an elf executable.

No makefiles required! It's all aarrp!

Worth thinking about how we would implement incremental builds with this.
* If we're writing our own assembler in machine language, could we share this assembler implementation for fully-verifiable bootstrapping? Could we writing it in a simple file format like stage0 "hex", then for the in-aarrp implementation include and parse it into aarrp structures?
* I don't like that byte_buffer stuff needs to be part of the public interface with the current
  design, and used when implementing macros. I want byte_buffer to be an implementation detail and I want as minimal of a public interface as possible. I think we need to rethink this interface.
    * macro(*input_structure, *cleanup_out) -> absolute output pointer or NULL for nothing. Macro writes a pointer to a cleanup function to *cleanup_out such as free() or byte_buffer_free() if it wants aarrp to free it's data when it's done with it.
    * macro(*input_structure, *macroexpansion_struct) with struct arg representing macroexpansion with cleanup func and such
    * counter-argument: the byte_buffer functions like byte_buffer_push_barray are highly convienient for constructing output, and if we're going to provide this as public anyway we may as well use it as the default interface.
        * but of course, this could all still be implemented inside aarrp-land.
        * that said, generally, we need at least the stuff required to reasonably write an assembler in machine language built-in. Most macros need to be able to produce dynamically sized outputs, and needing to implement a byte buffer in machine language for every platform first probably isn't ideal.
* We want to limit the amount of builtin functions available to macro as well. We plan to give users the ability to define build-time functions of their own in some way.
* I'm starting to think that there should be no self-hosted implementation. I want to encourage everyone to go through fully verifiable bootstrapping paths, and aarrp is so simple the assembly implementations can be well-optimized. Either way we need an assembly implementation per-platform to bootstrap.
    * counter-argument: not every platform needs a bootstrap implementation necessarily, as aarrp can be cross-compiled from another machine or through virtualization as a bootstrap process. A self-hosted implementation could then cover a wider range of platforms
* We probably want to give the user access to the macro stack functions in user-defined macros (by providing macros like (aarrp/builtin-func-addr/macro_stack_push)), as well as give them access to generally anything else we do with builtin macros that we're willing to standardize as a public interface
* Make sure we give the user access to push/pop reader and printer macros within a structural macro implementation
* Rename macro_stack to function_stack? We're probably going to use it for build-time functions that you can specify and use in your macros too.
    * Or maybe even just "stack": We may also use this for a stack of arbitrary data blobs, like for storing error strings
* We probably with a nice way to do (aarrp/with-data ((my-str "foobar") (my-other-data "\xFF\xFF"))). Perhaps using what we currently call the "macro stack".
    * Make it store aarrp structures, not just barrays. You should be able to say (aarrp/with-data ((my-data (foo bar baz)))).
* If we use the macro-stack for non-executable things, make sure we can create a macro stack that uses non-executable memory.
* This might be a nicer way to check stack alignment:

%macro safe_call 1
    %ifdef ASSERT_STACK_ALIGNMENT
        call assert_stack_aligned
    %endif
    call %1
%endmacro

then use safe_call everywhere instead of call.
* We might need a way for macros to expand into a "spliced" list - AKA (foo (my-macro)) expanding into (foo a b c).
    * This also might be logically broken: what if you call a splice macro at the top level?
    * Wanting to use this also generally implies you're making assumptions on who your parent macro is, which is wrong.
    * You could probably work around the lack of this in general by using a parray-cat macro
    * this would also break our "shy macro expand" pattern in stuff like with and with-macros
* We need to think about how build-time macro libraries could be distributed.
    * They could potentially be distributed as .so files that contain a function you can call to push all of it's macros - or simple all of it's macros listed as data with a symbol to reference them (a "global"). aarrp could have a standard way of loading these with (load-so-macros).
        * This is fancy because you could include both runtime library components and buildtime components in a single .so file.
    * They could be distributed as raw .aarrp files of source, but that would require building all build-time dependencies from source everytime (slow)
    * They could be distributed as raw aarrp structures fully macroexpanded (compiled) in binary format, maybe call it something like file.aarrpb64.
    * .arrpb format with the header specifying the pointer/array length sizes + endiannes and (includeb) macro that can import arbitrary-sized structures.
        * this is probably the best default approach
    * Users can always build their own solutions (though includeb makes sense as a builtin I think).
* Right now if you do ((macro-that-expands-into-nothing-barry)), it expands literally into (nothing) even with a nothing macro defined. If this is a problem and we want to fix this, we probably want to repeat the entire macroexpansion process repeatedly until nothing expand.
    * We probably want to fix this even though I can't think of a use-case: feels more complete and I think it's logically correct
* We probably want a (with-masked-macros (foo bar baz) my-form) that disables those macros for my-form.
* in my IR I should call mov cp because that makes more sense
* We want to make sure we expose the relevant builtins in such a way that an aarrp user could create their own (macro,data,etc) stacks
* It should be possible to implement executable macros even on a platform that doesn't support executable memory by simply writing out executable files or w/e else. This can still be abstracted away nicely in the label stack because we simply have functions in the label stack implemntation to call the value.
* Because executable memory is not an assumed property of the platform, the publicly exposed version of malloc probably shouldn't allow executable as a flag. The public version could call malloc_linux which does have such a flag, and thus internal components could use malloc_linux on the linux platform.
* To define build-time functions, you could use with-data and mark the data as executable.
* If we had a parray-cat builtin, you could include multiple different .aarrp files with macro lists and use them all in one with-macros call.
* it might be useful for barray-cat to have an (aarrp/barray-cat/offset-labels 5) that counts as an offset as that element is hit.
* We need to make our own indentation profile for neovim (treesitter?).
    * I don't like that how w/ lisp we indent things differently depending on if we're working with data, a function, or a macro. It's all data and we should be consistent, right?
* A namespacing alias macro like (with-namespace-aliases ((asm wentam/asm/x86_64)) (asm/mov rdi 5)) would be handy.
* We need to establish clear namespacing rules. Current thoughts:
    * All macros should be namespaced, because a sub-language might want to use that same name.
        * But this might be weird - like if "if" is a macro: (wentam/my-cool-programming-language/if (= 5 5) foo) - could be cumbersome.
    * Forms that hold meaning inside a specific macro - like the labels in barray-cat, do NOT
      get namespaced because a sub-macro using those terms won't have our logic apply. We don't
      want to make namespaces too cumbersome.
* when implementing our ELF macro, we probably want it to expand into a barray-cat w/ labels, supporting labels within the ELF macro so we can define symbols and stuff
    * When you define a symbol for a function in a relocatable .o, the value of the symbol is relative to the start of the .text section. We need to reference it in a different section.
        * This means the semantics of the situation are a little bit more complex, and thus it may be the ELF more-or-less implements it's own label system semantically (even if it compiles into barray-cat).
* when designing macros/abstractions, it's probably best to make sure "list of X" is always actually a list, even if it doesn't need to be. Example: with-macros has you define macros in a list, even though we could infer that the last element is the expansion.
  This is generally desirable because we want to make sure a macro can also expand into "list of X". At the time of this writing, splicing isn't a thing and I'm not sure it should be a thing.
  * Currently, barray-cat doesn't work this way - you just do (barray-cat a b c) and not (barray-cat (a b c)). We might want to change this.
* We might do better implementing the ELF macro in smaller steps: implement an (elf/relocatable/header ) macro that expands into an ELF header for example.
    * To be able to reference things like symbol values, we would probably need the barray-cat absolute label ref thing, as well as add and subtract macros to make them relative to the right thing.
* Add macro that adds binary values of n-byte width, as well as a macro to convert ascii numbers to binary values and a macro to negate binary values so you can subtract using the add macro.
* Right now we have barray-cat to have label-rel-ref in barray-cat produce values relative to it's RHS. This is because that's what x86_64 instruction encoding wants. We probably want to make it configurable though as a flag because
  not everything will work that way.
* TODO we probably want binary literals like \b00000001 in byte strings
* comments at the top of a file prevent the reader from getting to the first form
* I don't think we need overly-complex dispatching rules for reader macros like regex or anything: when what we have isn't flexible enough, you can just implement a catchall reader macro that consumes everything and resolves it all internally.
* random thought regarding register assignment

You could allocate a register like (allocate rax "my code") that would reserve that register for the duration of your code. If anything inside your code allocates that register, that register is automatically pushed out of the way and popped afterwards. You only ever use registers that you've allocated.

functions you call could still, of course, nuke non callee-preserve registers.

UPDATE LATER: actually, allocate could push/pop your allocated register around function calls.

* Or perhaps you don't allocate a specific register, but *any* register. It's up to the register
allocation macro what register to give you depending on it's content. More likely to give you
a callee preserve register if you call functions.

Allocate could push/pop your allocated register around function calls if it's not a callee preserve register though. As an optimization in this case, it could instead choose to use a memory location to avoid push/pop.

This really makes it more like "allocate a slot" that may or may not be a register.

The biggest problem with the "use a memory location" optimization is that not all instructions can use memory in place of a register. Thus, the allocate macro would have to be "smart", recognize this situation, and automatically use a temporary register. To do this, it would probably expand into an explicit allocate-register macro that *always* gives you a register even if you need to push/pop.

Thus, an allocate-register macro that only does registers (but no particular register) is still needed first and the basis of this. This is awesome because it "simulates" having infinite registers in a reasonably optimized way.

This macro could be step 1 in working our way up towards an IR.

obviously would need to be surrounded by (x86_64-asm/with-register-allocator (list-of-callee-preserve-registers) my-code)

It's arch-specific because the allocator needs to understand stuff like what a function call looks like, what instructions allow memory operands etc.

Because pushing/popping a register around function calls can misalign the stack - and we don't want to waste the extra sub rsp,8 add rsp, 8 instructions when we dont need to - the top-level macro should probably sneak in and align the stack before all function calls.

Or maybe aligning the stack around function calls is a separate macro altogether - could be interesting.

Because of the scope with (with-register-allocator), you could assign callee preserve registers based on something like who has the most function calls of all the allocators. The optimal implementation of this is clearly scope-wide. Because of this, perhaps
the allocate-slot and allocate-register guys are not macros. Thinking about it, I think that makes the most sense.

I think the condition in which we want to start using memory locations is when we're out of callee-preserve registers and our allocation covers 2 or more function calls. With 1 function call it's probably better to just push/pop around it.

Beware of situations like:

(allocate-register my-reg1
  mov my-reg, 5
  (allocate-register my-reg2
    mov my-reg2, 7
    add my-reg2, myreg1))

It's important the allocator doesn't give both of these the same register. Even with push/pop, there's no way to make it work right without separate registers or memory locations.

This isn't true of all nesting, just nestings where the inner uses a register from the outer in it's content. In other words, I think it's something like:
When allocating a register for an allocate-register block, all registers used inside the block that parents have allocated cannot be the choice for my own register.

Interestingly, that means that even with this design there are certain situations where you can run out of registers with allocate-register alone, highlighting the absolute necessity of allocate-slot.

* disassembler macros?
* do we want to support barray macros, not just parray? (as in macros where a barray directly expands into another structure)
    * It feels like to be generally flexible the answer is probably "yes". It would be simple to add as well.
    * Any user who disagrees can simply not use it.
    * Use case example would be build-time "variables"
* Does the macro stack need to be global? What if the with-macros macro simply created a macro stack? Yes, we would have nested macro stacks, but we don't expand everything at once.
    * Puts even more behavior exclusively in the macros - which users can define - and thus less builtin "magic"
    * Smaller relevant search space for stack operations.
    * Would still need to be a top-level macro stack for builtin macros to expand.
    * structural_macro_expand would need yet another argument
* If you just build a language with macros that implements your language's behavior entirely at aarrp expansion time, you have a JIT-compiled language
    * Also worth observing that at build-time in a compiled language, you're still working with a JIT language.
    * This means you could build a javascript JIT implementation inside aarrp (I wonder about building a JS engine, maybe use it w/ ladybird browser).
* In fact, aarrp can cleanly serve as all 3, making this a truely universal language-building tool:
    * ahead-of-time compilation: macros expand into machine code and written to ELF via ELF macro
    * interpreted: use macros for their side effects
    * "eager" JIT (compile at function definiton time): just like ahead-of-time, except your code expands into a macro instead of an ELF to define a function. Using the macro (inside another macro definition) is calling the function.
        * This means when you build your ahead-of-time language, you can simply just use it like a JIT language without modifications.
    * "lazy JIT" (compile at first function use): create your own with-macros macro that doesn't macroexpand the macro until it's used.
        * Optionally inline the macro instead
* When trying to optimize codegen, I'd like to look at what existing compilers output for the same thing, but *don't* look at how they do it. I want to explore my own bottom-up way. Things like my allocate-register macro described here are a good example why.
* the first optimizer worth implementing is probably a recursive inliner. Ideally this would be done at the IR level (by having an inliner macro that inputs IR and expands to IR with inlining done).
* If an optimization can be done at the IR level, it should probably be done at the IR level (by having optimizer macros input IR and expand to IR with the optimization in place) rather than assembly or higher-level language.
* Idea: re-implement nasm inside aarrp. Now we're self-hosting without actually having a separate impl.
* Pretty early on, we probably want to implement aarrp and some of our abstractions on a few different platforms to make sure we're doing portability right:
    * something not 64-bit, but with an OS (x86?)
    * something with a different OS (windows maybe?)
    * something embedded (8-bit AVR probably to represent the minimal case)
    * andy bots game (RISC-V and represents simplified virtual platforms)
