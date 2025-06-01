## it's a bunch of stuff

I have a bad memory and think a lot. I like to keep 'brain dump' files like this around. It's like the human version of swap space. Consider this my bb one. Do not expect it to have a clean structure.

Note to self: keep these notes around even after stuff is implemented so I can remember why I did things! I often forget. Maybe move old, less relevant notes to a diff file tho at some point.

Try to re-read this occassionaly when working on bb so we remember important things.

Notes:
* The macro stack was renamed to kv stack later on, and many of these notes predate this change.
* 'with-macros' was merged with 'with' at some point to allow for interdependencies between the two to be shipped as one unit.
    * 'with' just did data at first, not macros

## the stuff

* Blurbs

"first-principles reductionist simulator"

machine language with macros.
A language where syntax, semantics, and structure are yours to define.

* We need structural macros like (with-popped-printer-macros (barray) (my-form)) that expand (my-form) without
specific printer macros present
* There should be no command line arguments to the bb binary whatsoever to avoid the platform-dependent and implementation-dependent nature of that, and the fact that we want everything to be standardized. See some of the points below on how this can be avoided. Also see tag [A] in this file.
* important: bb ALWAYS only evaluates one form from the input, there is no implicit top-level list or anything like that. bb will provide a way to wrap the input in some top-level form, so if you want you can wrap in a list or in a macro entering your language of choice. See point below about how to wrap without command line arguments in a really flexible way.
* If something doesn't need to be a builtin macro, IT SHOULD NOT BE. We want the core to be as minimal as humanly possible. We also want fewer builtins that language builders have in their namespace.
* To wrap your input in something, just use (include "file.bbr") in your input to bb to template it. Example: echo '(with-popped-printer-macros (include "my-real-code.bbr")) | bbr'. This might be most ergonomic if 'include' is a builtin macro, though think about if there's a good way to avoid this.
* [A] If you want to define a "compile-time variable" like -D to define something, do that by wrapping at CLI time like above with a macro (not builtin) that defines them. echo '(with-macros (include "my-language.bbr") (with-my-language (with-defined (LINUX X11 WAYLAND) (include "my-code.bbr"))))' | bb. This approach is more flexible as the "CLI" arguments that are supported are not hardcoded into bb, and the arguments aren't implementation-defined.
* It would be cool to have the ability to "watch" macroexpansion happen step-by-step where pressing spacebar or whatever advances one expansion. This should not be done with a CLI argument, but a macro that implements this behavior printing as it goes (macros can have side-effects!)
* Should macros pushed with push-macro automatically pop at the end of the "scope"? Right now the behavior is a little bit confusing, as something very nested could push a macro that is then applied to something at the top-level. I also don't want to force the user to be so intricitally aware of macroexpansion order or make exact macroexpansion order incredibly important in the implementation.
  Perhaps what we want instead is a (with-macros) macro. Could also support both, document the caveats of (push-macro) clearly. Though once you have one, you could implement the other inside the language.
* Or maybe only have push-macro without pop-macro? It would just be the 'global' version, and we would basically have defmacro and macrolet both in the base language.
* We probably need a builtin macro that expands into the platform of the bb binary, such that for macros your language macro knows what type of machine code to expand into. Maybe: (bb-platform) expands into "x86_64-linux" (bb-cpu) expands into "x86_64"
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
* Typical programming language compilation command example: $ echo '(with-macros (include "my-language.bbr") (with-my-language (with-defined ((OS LINUX) X11 WAYLAND) (include "my-code.bbr"))))' | bbr 
                                  Or with the 'with' macro: $ echo '(with ((macros-from "my-language.bbr")
                                                                           my-language
                                                                           (defined ((OS LINUX) X11 WAYLAND)))
                                                                      (include "my-code.bbr"))' | bbr
* Or maybe just have a 'nest' macro:
  (nest (with-macros (include "my-language.bbr"))
        (with-my-language)
        (with-defined (stuff))
        (include "my-code.bbr"))

  Expands into:
    (with-macros (include "my-language.bbr")
      (with-my-language
        (with-defined (stuff)
          (include "my-code.bbr"))))

  This solves the problem more generally.

* You could also argue that not using a 'nest' macro and just using a different indentation style solves the problem nicely:
    (with-macros (include "my-language.bbr")
    (with-my-language
    (with-my-library
    (with-defined (stuff)
      my-code))))

This feels a little bit wrong, but so does spending build compute time on a 'nest' macro that really just changes how you indent it.

* in my higher-level language, probably call (let) (with-vars) instead to stay consistent with the 'with' pattern.
* When we say (with-macros (include "foo.bbr") (with-macros (include "bar.bbr") my-code)), the macros from foo.bbr would be available inside bar.bbr. This isn't *that* wierd, as it behaves the same way in C with #include, but we might want to provide a mechanism that locally reverts to just builtin macros, like (with-only-builtins foo). with-macros - or another macro with a similar name, could automatically use with-only-builtins.
* Note that you could build an interpreted language in bb by using macros for their side effects instead of what they expand into. Could implement python inside bb like this.
* It's definitely worth documenting clearly that macros are about both expansion *and* side-effects, unlike in CL
* Because macros are about side-effects, there's definitely an argument to be had that maybe macroexpansion needs a specified, deterministic order
* A naming scheme that differentiates between a build-time thing and a runtime thing would probably be helpful, like (push-function) and (runtime-function)
* include probably needs to be a builtin macro. Yes, you could implement it in bb, but there would be no way to include the include macro as a library.
* idea: markup language like markdown/latex implemented via bb macros (expands into some renderable format?)
* should bb understand that there are different platforms for machine code? When defining a macro, you could define ((x86_64 "machine_code") (risc-v "machine_code")) to support different platforms for macro execution. This could also be left up to the user to resolve by having the user access an (bbr-platform) macro and switching themselves. This may make sense to occur in bb though, because bb's core functionality has to do with the execution of machine code. Building this into bb would avoid undefined behavior if you accidentally choose to execute machine code from one platform on another, and building this into bb would be very very simple (the x86_64 implementation of bb just needs to always look up the x86_64 machine code.)

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

Currently strongly leaning towards resolving it within bb. Avoids undefined behavior, can easily emit a warning if you define a macro without an implementation for the bb execution platform, can easily emit an error when you try to call a macro when there isn't an implementation for the bb execution platform, more ergonomic, doesn't really add complexity to bb (but would be a bit complex to do it inside the bb language), completely thetical to bb's role as managing the execution of machine-language macros. Implementing this yourself inside the bb language would *not* allow you to produce a nice error upon macroexpansion, so I think this is a must.

Question is: is this by cpu arch? x86_64, arm? or By platform: x86_64-linux, arm-windows. My current intuition says platform: I think you want a separate entry to occur per implementation required - which itself is a good way to define "platform" within bb. Windows and linux have different "system" apis, linux with syscalls and windows with win32, and this demands separate implementations.

This does result in a combinatorial explosion of assemblers required to be implemented in machine language inside the bb language, but I think that's just reality.

Note: to avoid actually running an assembler/compiler for all supported platforms when defining a macro, you could have your IR assembler/compiler accept an instruction to only produce a specified platform - then pass it (bbr-platform).

Another interesting thing to note is that this would allow bb implementations to do some weird stuff like support execution of macros written for another platform through virtualization. This is actually a good argument to NOT have your IR assembler expand into only one but always provide all options. This is actually really interesting because it doesn't actually assume what our host platform is, we're just listing the ways we know how to accomplish the task and letting the bb implementation choose whichever it knows how to execute best. It's also probably not that big of a deal to have your high-level language expand into all, because this portability is implemented at the IR level which should be a case of quick assembly for all.

If needing to assemble and optimize the IR 20 times is too expensive, bb implementations could also provide a list of the macro execution platforms it supports sorted by priority, and the IR could limit it's expansions. Probably also providing stubs for other supported platforms so you can still see a list of supported platforms inside bb.

Another perspective: this is actually a little bit weird, because you only ever need one platform at a given time. (with-macros) could also always only accept the correct machine code for the bb execution platform, and you could also provide a (select-platform) macro that expands into the relevant platform for convenience:

(with-macros
  ((elf64-relocatable
     (select-platform
       (x86_64-linux   "machine code")
       (risc-v-windows "machine code")))))

The downside of this is the inability to have nice errors if you try to execute a macro on an unsupported platform.

* Due to the above, we could support a lot of platforms easily by for example using box64 in an ARM implementation of bb to support macroexpansion.

* To bootstrap bb, we could implement it once in as simple of an assembly language as possible - like RISC-V - then demand that those who wish to bootstrap must run a RISC-V virtual machine. If you keep it to a minimal portion of the risc-V instruction set, said VM could be very simple. We could even write some VMs.
* Idea: support execution of macros written for a different platform/arch through virtualization in more advanced implementations of bb.
* Helpful line for documentation purposes: "bb exposes all levels of abstraction for you to see and interact with, including machine language."
* Once we have a high-level language, a video walking through the abstractions bottom-up would be a great way to demonstrate what bb is about.
* We probably want to implement macros in the bb language (not builtin) for elf executables (not just relocatable object files), as well as implement a linker directly in macros. That way, you can actually specify your entire build process directly inside bb.

(link-elf-executable (elf64-relocatable foo) (include "somefile_with_elf64-relocatable.bb"))

Would expand into an elf executable.

No makefiles required! It's all bb!

Worth thinking about how we would implement incremental builds with this.
* If we're writing our own assembler in machine language, could we share this assembler implementation for fully-verifiable bootstrapping? Could we writing it in a simple file format like stage0 "hex", then for the in-bb implementation include and parse it into bb structures?
* I don't like that byte_buffer stuff needs to be part of the public interface with the current
  design, and used when implementing macros. I want byte_buffer to be an implementation detail and I want as minimal of a public interface as possible. I think we need to rethink this interface.
    * macro(*input_structure, *cleanup_out) -> absolute output pointer or NULL for nothing. Macro writes a pointer to a cleanup function to *cleanup_out such as free() or byte_buffer_free() if it wants bb to free it's data when it's done with it.
    * macro(*input_structure, *macroexpansion_struct) with struct arg representing macroexpansion with cleanup func and such
    * counter-argument: the byte_buffer functions like byte_buffer_push_barray are highly convienient for constructing output, and if we're going to provide this as public anyway we may as well use it as the default interface.
        * but of course, this could all still be implemented inside bb-land.
        * that said, generally, we need at least the stuff required to reasonably write an assembler in machine language built-in. Most macros need to be able to produce dynamically sized outputs, and needing to implement a byte buffer in machine language for every platform first probably isn't ideal.
* We want to limit the amount of builtin functions available to macro as well. We plan to give users the ability to define build-time functions of their own in some way.
* I'm starting to think that there should be no self-hosted implementation. I want to encourage everyone to go through fully verifiable bootstrapping paths, and bb is so simple the assembly implementations can be well-optimized. Either way we need an assembly implementation per-platform to bootstrap.
    * counter-argument: not every platform needs a bootstrap implementation necessarily, as bb can be cross-compiled from another machine or through virtualization as a bootstrap process. A self-hosted implementation could then cover a wider range of platforms
* We probably want to give the user access to the macro stack functions in user-defined macros (by providing macros like (bb/builtin-func-addr/macro_stack_push)), as well as give them access to generally anything else we do with builtin macros that we're willing to standardize as a public interface
* Make sure we give the user access to push/pop reader and printer macros within a structural macro implementation
* Rename macro_stack to function_stack? We're probably going to use it for build-time functions that you can specify and use in your macros too.
    * Or maybe even just "stack": We may also use this for a stack of arbitrary data blobs, like for storing error strings
* We probably with a nice way to do (bb/with-data ((my-str "foobar") (my-other-data "\xFF\xFF"))). Perhaps using what we currently call the "macro stack".
    * Make it store bb structures, not just barrays. You should be able to say (bb/with-data ((my-data (foo bar baz)))).
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
    * They could potentially be distributed as .so files that contain a function you can call to push all of it's macros - or simple all of it's macros listed as data with a symbol to reference them (a "global"). bb could have a standard way of loading these with (load-so-macros).
        * This is fancy because you could include both runtime library components and buildtime components in a single .so file.
    * They could be distributed as raw .bbr files of source, but that would require building all build-time dependencies from source everytime (slow)
    * They could be distributed as raw bb structures fully macroexpanded (compiled) in binary format, maybe call it something like file.bbrb64.
    * .bbrb format with the header specifying the pointer/array length sizes + endiannes and (includeb) macro that can import arbitrary-sized structures.
        * this is probably the best default approach
    * Users can always build their own solutions (though includeb makes sense as a builtin I think).
* Right now if you do ((macro-that-expands-into-nothing-barry)), it expands literally into (nothing) even with a nothing macro defined. If this is a problem and we want to fix this, we probably want to repeat the entire macroexpansion process repeatedly until nothing expand.
    * We probably want to fix this even though I can't think of a use-case: feels more complete and I think it's logically correct
* We probably want a (with-masked-macros (foo bar baz) my-form) that disables those macros for my-form.
* in my IR I should call mov cp because that makes more sense
* We want to make sure we expose the relevant builtins in such a way that an bb user could create their own (macro,data,etc) stacks
* It should be possible to implement executable macros even on a platform that doesn't support executable memory by simply writing out executable files or w/e else. This can still be abstracted away nicely in the label stack because we simply have functions in the label stack implemntation to call the value.
* Because executable memory is not an assumed property of the platform, the publicly exposed version of malloc probably shouldn't allow executable as a flag. The public version could call malloc_linux which does have such a flag, and thus internal components could use malloc_linux on the linux platform.
* To define build-time functions, you could use with-data and mark the data as executable.
* If we had a parray-cat builtin, you could include multiple different .bbr files with macro lists and use them all in one with-macros call.
* it might be useful for barray-cat to have an (bb/barray-cat/offset-labels 5) that counts as an offset as that element is hit.
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
* If you just build a language with macros that implements your language's behavior entirely at bb expansion time, you have a JIT-compiled language
    * Also worth observing that at build-time in a compiled language, you're still working with a JIT language.
    * This means you could build a javascript JIT implementation inside bb (I wonder about building a JS engine, maybe use it w/ ladybird browser).
* In fact, bb can cleanly serve as all 3, making this a truely universal language-building tool:
    * ahead-of-time compilation: macros expand into machine code and written to ELF via ELF macro
    * interpreted: use macros for their side effects
    * "eager" JIT (compile at function definiton time): just like ahead-of-time, except your code expands into a macro instead of an ELF to define a function. Using the macro (inside another macro definition) is calling the function.
        * This means when you build your ahead-of-time language, you can simply just use it like a JIT language without modifications.
    * "lazy JIT" (compile at first function use): create your own with-macros macro that doesn't macroexpand the macro until it's used.
        * Probably by pushing 'dummy' macros that macroexpand and push the real macro to the stack upon first use.
        * Optionally inline the macro instead
    * macroexpansion = compilation, so any kind of JIT is possible by simply choosing when to macroexpand.
* When trying to optimize codegen, I'd like to look at what existing compilers output for the same thing, but *don't* look at how they do it. I want to explore my own bottom-up way. Things like my allocate-register macro described here are a good example why.
* the first optimizer worth implementing is probably a recursive inliner. Ideally this would be done at the IR level (by having an inliner macro that inputs IR and expands to IR with inlining done).
* If an optimization can be done at the IR level, it should probably be done at the IR level (by having optimizer macros input IR and expand to IR with the optimization in place) rather than assembly or higher-level language.
* Idea: re-implement nasm inside bb. Now we're self-hosting without actually having a separate impl.
* Pretty early on, we probably want to implement bb and some of our abstractions on a few different platforms to make sure we're doing portability right:
    * something not 64-bit, but with an OS (x86?)
    * something with a different OS (windows maybe?)
    * something embedded (8-bit AVR probably to represent the minimal case)
    * andy bots game (RISC-V and represents simplified virtual platforms)
* Should barray-cat allow you to "splice" a macro that expands into a parray? like (bb/barray-cat foo bar (splice (some-macro foo)) baz) where some-macro expands into a parray whose elements get semantically spliced into the barray-cat.
    * Another example: (bb/barray-cat foo bar (splice (1 2 3)) baz) is semantically the same as (bb/barray-cat foo bar 1 2 3 baz)
    * Using this, an assembler implementation could have a 'mov' macro that works as follows: (mov rdi (label-ref foo)) -> ("\xFF\xFF" (label-rel-ref foo 4 LE)), then you can splice it in.
        * Could go even further: (mov rdi (label-ref foo)) -> (splice ("\xFF\xFF" (label-rel-ref foo 4 LE)))
        * It's debatable if this is a good design for an assembler though, as in this case we're making the assumption that the instruction is ending up inside a barray-cat - and making assumptions about our expansion environment is usually a bad
          design.
* for better error reporting, we should maintain a "macro call stack" in memory, probably using kv_stack. Every time we call a macro, it enters the stack, removed when it returns.
    * This means we need a standard "call structural macro" interface, don't pull it out of your kv_stack. Maybe put this in structural_macro_expand's file - and call it structural_macro_call.
    * error-exit/error_exit should dump this stack on error.
* Right now, builtin function addresses are provided through macros like (bb/builtin-func-addr/byte-buffer-new). This is pretty simply when the bb implementation only supports one platform, but if the bb implementation supports multiple,
  we need to think about this a little bit.
    * The implementation could temporarily push a different macro that expands into that platform's address format while evaluating each platform
    * The builtin function address macros could allow you to specify the format - like (bb/builtin-func-addr/my-func 4 LE).
        * This is probably the most flexible solution, as we shouldn't assume you're using the function address for use in defining macros.
        * Could make it so the old way still works, but emits a deprecation warning if you do it that way.
    * Actually no: you care about what platform the function is for. If you have an bb implementation that supports multiple platforms for macro execution, thus you want (bb/func-addr/my-func x86_64-linux). This would expand with the width
      and endianness relevant to that platform - not user-specified because we need to be able to access that whole platform's address space.
* A fancy self-hosting implementation of bb written from a higher level of abstraction, optimized, and supports executing macros written for a lot of different platforms through virtualization would be a nice "practicality" design choice.
    * Just make sure it's bootstrappable always through the assembly versions
* Our high-level language should always support at least 64-bit integers, even on platforms like AVR. Much like C. Once in the high-level language, you should be abstracted away from the target platform.
    * Maybe bignums too, though explicitly sized integers are needed for perf as we learned in my CL work.
    * We might want to implement this at the IR level - I lean that way.
        * What about IR-level bignums? Language designers can choose not to compile into them.
            * I like the idea of my high-level language having a natively supported bignum type.
        * Probably implement through an "integer reduction" pass, IR-to-IR.
* desirable features in high-level lang:
    * named parameters (IIRC CL was good at this)
    * multiple return values - ideally access by name.
    * multiple dispatched objectss like CLOS - but with fast static dispatch, not dynamic
    * auto-generated accessor methods like CL
* My thoughts on procedural vs declarative languages
    * One is not more fundamental than the other. The fact the logic = truth and truth is stateless is an arbitrary human invention.
    * Declarative languages are better at modeling inherently declarative problems. If the problem is "define how this system is configured", nix wins.
    * Procedural languages are better for modeling everything else.
    * We're using bottom-up abstraction upon procedural CPUs, thus a procedural language will probably form first.
    * We naturally think procedurally and this makes it a natural choice for general purpose computing
    * As a point of evidence that one regime is not inherently better, the empirical process of evolution produced the human brain which applies both ideas - procedural and declarative components.
    * Machine learning is better at solving declarative problems.
* Modeling abstractions vs problem space
    * A problem is a dot.
    * An abstraction is a line, usually horizontal
    * Create a chart where the X axis is the problem space and Y axis is abstraction level.
    * Machine language would be a very wide box but short box: it covers basically all problems,
    but is a very low level of abstraction.
    * Common lisp would be a narrower and very high up line.
* My thoughts on string formation (interpolation etc)
    * When writing a value stored in a variable into a string, we need to know not just the type of the variable, but the output format that we desire. An integer could be written in base 10, 2, 16. We might want it padded to certain width etc.
        * Most languages with string interpolation simply make a best-guess assumption without configurability. This is wrong.
    * printf and CL (format) does not make these assumptions for the user. This is correct.
    * It may be possible to have string interpolation that also has you define the expansion format: "count: ~id( x + y )" or "memory address :~ix( x + y )"
    * If there is string interpolation, we should allow for arbitrary expressions.
    * There's nothing that says you need one or the other - templating or interpolation: (format "my num: ~id(x + y) my other num: ~d" z). Why not both?
    * String interpolation can apply to more just format/printf like function calls - and can be more general-purpose. This is desirable.
    * bb uses \ as an escape character for byte strings at a low level. Because string interpolation would be a runtime task, we probably need a different escape character for runtime. Maybe '~' to remain lisp-consistent.
        * Maybe even 3: \ for build-time/bb-time, ~ for macros like 'format', % for interpolation with every string.
            * This might be confusing or annoying to manage to have 3 diff escapes. 2 is already atypical.
                * ~i could mean interpolate instead to help manage this
    * There could be both build-time *and* runtime string interpolation using the two diff escape chars
* Minecraft command block compilation target would be fun and probably popular
* mindustry computer compilation target?
* we probably want a webassembly implementation of bb itself, so you can play with bb in a web browser
* (with-templates) - a macro that allows you to define things like 'with', but the things you define can accept parameters to be used as part of the expansion like C macros.
    * You could argue these are basically "declarative macros"
    * could maybe just be the normal behavior of 'with', since this could fill both roles.
    * Once you reach a high level of abstraction where the language can behave in a more declarative way, with-macros fills both roles. Thus, with-macros feels more "fundamental". with-templates would just be a bootstrapping convienience.
        * Because of this, I don't think with-templates should be a builtin. We should try to keep things simple
* 'with' could also fill the role of with-macros, you just need to tag an entry as a macro
    * Doing it this way would let you distinguish general build-time functions vs macros more easily when reading code, as when you end up with tall code you lose the context of the 'with-macros' call.
* should 'with' even be builtin?
    * It's not really fundamental like macros are - you can build it with macros (it's just a builtin macro)
    * It's useful for bootstrapping a language
        * I lean 'yes' for this reason. While I want to keep things as minimal as possible, we need *some* bootstrapping ergonomics.
* We need to expose builtins for both pushing/popping macros and stuff w/ kv_stack.
    * This means we need macros to expose the global macro stack addressess
* We should prove we can re-implement all builtin macros in the language by simply doing so. There aren't that many.
    * Will help us find holes - will probably find things we forgot to expose like builtin functions or bb-side state that we need.
        * Fundamentally, bb-side state is the only stuff you should need, though because some of the internal data structures are implementation-defined in terms of memory layout and such,
        some functions are practically required for portability.
* for our high-level lang, it would be cool if you could enter a 'pure' declarative subset of the language just by going (pure {stuff})
* A good argument for implementing C inside bb is that we could gain the ability to import C header files like zig does for easy FFI.
* Another argument for implementing C: direct apples-to-apples comparison of optimizer to existing C compilers
* We need line numbers in errors. This may require accomodation in bb itself - because we're destroying this metadata right now at read time. Perhaps the readers needs to produce a secondary tree of identical structure to the input, except with all barrays replaced with their corrisponding line numbers.
* In order to encourage clean macros, we mighht want gensym builtins
* We may change the exact interface macros use in time. Thus, with-macros - or each macro definition inside it - could specify a 'macro protocol version' that the macro is defined in. This would allow for backwards compatibility if we changed the interface.
    * It's okay if we implement this later, because we can just say if no version is specified, assume X version and emit a deprecation warning.
    * It's important to allow for the core of bb to improve as we learn more about how best to solve it's problems. It's best to avoid breaking changes along the way.
* What if parrays used relative pointers?
    * This would avoid lots of "pointer to dynamic memory allocation" type bugs like with pointers into a byte buffer that might grow
    * This assumes our data is local to us in some way, which might not always be true, so less flexible.
    * Maybe some way to support both relative and absolute addressing is in order?
        * Probably annoying because now when you're passed a parray it's complex to access it's values.
    * Absolute pointers seem to be the most complete answer. Just bug-prone with the amount of dynamic allocations our design demands.
    * bb/with is a good example of why we need absolute pointers - how would you reference a 'with' value by reference?
        * Absolutely needed for things like defining compile-time utility functions
* We might want the portable "buffer-relative pointer" form to be a specified and correct memory representation of bb structures in addition to the normal form.
    * Right now this form is used as an implementation detail in some places
    * Provide functions to convert between them (I think we already have relative to absolute in the bb binary)
    * Maybe provide a mechanism that allows macros to produce this form, and we can relative-to-abs internally.
* At least some of Rust's memory safety components would be very useful in our high-level language.
    * Look at how rust solves the problem where a dynamic memory allocation grows - like a std::vector - invalidating pointers to it.
        * Alias XOR mutate - "No aliasing while mutating" - If you have a reference, nobody can mutate.
            * Works this out at compile-time, so no overhead.
            * References, not pointers at this level.
        * This situation is a constant pain with our byte_buffer allocations in bb.
    * Any rust-style memory safety should be easily disabled and moved out of the way, both globally and locally.
        * There are corner cases where it probably gets in the way.
* byte buffer 'safe mode' - if enabled, instead of realloc, it creates an entirely fresh allocation and copies everything over, leaving the old allocation around.
    * Make it the default mode, user only turns it off as on optimization.
    * Track *all* allocations so you can free them all at once when done.
    * I think this means that we could remove a lot of the "buffer-relative pointer" complexity in stuff like the macroexpander.
    * Would this behavior be confusing? Mutations may suddenly not behave as the user expects.
        * Mutate at known pointer value, current relevant buffer remains unmutated.
    * Perhaps instead, 'safe mode' means that we allocate in chunks, and you *must* access through accessor functions only. No get_buf.
        * you need get_buf to write useful parrays.
        * Does introduce runtime complexity
        * Means it always behaves "as you expect" with pointers all remaining valid.
        * Actually no - I'm wrong - if you have a pointer to something along the chunk edges then read a whole bunch of bytes, you'll get garbage.
    * Yeah, this is a leaky abstraction: Imagine you 'get_buf' and 'get_data_len' to grab a pointer to the end of the current byte buffer, then write 1024 bytes to the buffer with the intent on that being the data the pointer refers to. But the buffer grows as you write it, and your pointer points to the stale block before the allocation. Now you have memory garbage.
    * Could only ever work if the behavior was made very clear to users
    * Probably just introduces different, more confusing memory management errors
* Maybe there should be two stages of IR: stage 1 = infinite normal registers, stage 2 = infinite SSA registers.
    * stage 1 design to more closely resemble how most cpus function allowing for as much optimization as possible away from the platform
    * this would make register assignment more platform-independent
    * To compile stage 1 to machine code, you could start by taking passes through the stage 1 IR to reduce the register counts to match available registers on the target platform.
    * Maybe both of these stages are the same IR - the IR just supports both SSA and mutable registers.
        * The optimizer expects everything to be SAA and errors on mutables.
        * Helpful because we likely want to do mutable->immutable->mutable again. It might be easier to build a language atop mutable registers. We optimize with immutable SSA. Back to mutable to generate machine code.
        * Explicit 'spill' instruction?
        * Allow mov memory, memory at the IR level, and only involve temps once compiled down?
            * Though if we disallow this, the spilling pain dramatically reduces on platforms where you need
            temps to spill
    * If it's helpful, the immutable->mutable transformation stage might write some tags about the mutable register to help compilers
        * For information easier to compute while registers are still immutable, but relevant to the lower levels
        * Like if the mutable register's usage crosses function call boundaries - useful for the IR->platform code compiler to know if they should prefer callee-preserve register if possible.
* Our IR should have good generic SIMD instructions
    * Can always compile down to non-SIMD on non-SIMD platforms.
    * Probably make it always possible to compile without SIMD support
        * Could do this by an IR->IR compile phase that converts SIMD-IR to non-SIMD-IR
* IR should have a raw instruction passthrough to allow for stuff like C's asm tooling.
    * Passthrough should declare what platform it's for, and an error should be produced if we attempt to compile that IR down to other platforms
* For the bb-side allocator, we could set up a bump allocator - allocating in 1MB chunks as needed - that is used for all tiny allocations. We have a lot of tiny allocations.
    * All other allocations can either use another allocation scheme or a syscall. Probably just a syscall at first, tiny allocations are our primary overhead.
    * Bump allocators exchange memory use for speed. At the tiny allocation scale - at compile time - we really only care about speed.
    * Anything bump allocated just doesn't get freed until program exit.
    * Play with thresholds, but probably bump allocate anything <= 1024 bytes, and probably actually syscall every 1MB. Maybe even progressively grow the syscall allocations.
    * Probably put a sanity cap on bump allocation at like 50MB.
    * Some logic to free a chunk if *everything* inside it is freed is probably still worth it. Probably do this by tracking allocation count per chunk. Increment on alloc, decrement on dealloc, free if zero.
* IR should
    * not use stateful nonsense like flags, this makes optimization hard and poorly maps to RISC arches
    * avoid side-effects at all costs in instructions. If side-effects end up being needed, compile a clear list of 'side-effect' instructions for the optimizer to know about.
    * be modeled after RISC-V - just SSA
    * Should have vector/SIMD operations
* We should pretend x86 is RISC and just use simple instructions when lowering
    * x86 is a dumb legacy platform and won't be relevant forever.
* As the quantity of macros grows, it actually may start to make sense to make with-macros lazy - push dummy macros that compile and push tho real macro upon first call, masking the dummy.
    * But also might not be needed because we plan to be able to package precompiled macros with the .bbrb format.
    * lazy with-macros means that the time at which you choose to expand the macro the first time potentially changes the behavior of the macro. I don't like this.
        * Because of this I'm in favour of greedy macro definition. Seems more logically correct.
* RISC-V assembler should not assume any extension, but enabled with args
    * When lowering IR to RISC-V, it should work fine without extensions but have slower codegen, because no SIMD etc
    * When lowering IR to RISC-V, take list of extensions.
* High-level language name idea: flaming parenthesis
    * parenthetic inferno
    * bb = spark, higher level = inferno?
        * kindling = IR
        * Cinder,ash,smoulder
    * bb = ember, higher level = blaze
    * kindling -> wildfire
    * cinder -> inferna
    * cinder -> wildfire
* For the web: what about building a RISC-V VM in webassembly
    * Give it a standardized mechanism of DOM access, maybe by memory-mapped I/O
        * Obviously this means it would need to be paired with a javascript glue library
    * Could create a webapp in an entirely bb-runtime defined way. Initial page load just loads
    JS glue and nothing else.
* Builtin macro: (bb/print-expansion foo). Macroexpands input. Prints result. Expands into input.
    * handy for debugging.
    * Expanding into input means we can stick this anywhere and have no effect on outcome, just injects the side-effect of printing the expansion along the way.
    * also print-expansion-1 to just do a macroexpand-1
* To optimize a program fully, you need the full picture. For example, without LTO in C, you can't inline a function from another .c. This leads me to wonder: is it realistic to just build everything as one 'translation unit'?
    * This doesn't mean a single file, as you can still use includes, but means the entire application is built without linking (aside from dynamic linking for third party libraries).
    * This would make it harder to scale compilation processes wide: right now bb is strictly single-threaded like most compilers.
        * It might be possible to get multi-threaded macroexpansion working - one parent with two children expands each child in a separate thread.
            * Means we wouldn't have as many ordering gaurantees for the user though.
            * The primary compilation cost in bb probably won't be bottlenecked on macroexpansion, but things like optimization passes
                * Optimization is generally per-function and could be parallelized without bb itself being parallel.
        * This also might be fine if bb remains super fast once we get to high-level compiler scale.
* should byte_buffer_new accept an argument for it's initial backing buffer size? our static size isn't always the ideal number - sometimes we might want something bigger to avoid reallocs (which are a bit expensive).
* We combined 'with' and 'with-macros' because we need to be able to ship interdependent macros, data, and functions as one unit. Using separate macros this is a problem for memory management reasons.
    * Before, if you wanted to return macros that depend on data you had a problem: once the 'with' macro expands, the data has beed freed.
* What if a macro can choose to *not* expand?
    * you can't just make a macro that expands into itself, that's recursive.
    * If a macro can say "no more", the macroexpander can leave it alone and not infinitely recurse
    * This allows for a build-time 'quote' macro that prevents macroexpansion.
    * macro returning -2 means don't macroexpand me anymore.
    * builtin macro using this: (bb/hold foo) expands right back into (bb/hold foo) returning -2 to prevent recursion.
        * When you're done deferring the expansion, just macroexpand 'foo' directly.
        * Not really any different than the barray approach below, just more complex and requires bb-accomodation.
* One way to defer macroexpanion would be to define a macro that takes an input structure and expands into a barray of the bytes that represent that structure (using our in-memory representation)
* We might want a way to inline builtin function calls in your macro if that overhead starts to matter
    * probably just define a macro (bb/builtin-func-code/byte-buffer-get-buf x86_64) that expands into the code.
* Rather than provide a platform-specific passthrough mechanism for things like syscalls, why not abstraction it? What if the IR had it's own version of a "syscall" layer that compiled down to linux syscalls, win32 calls etc.
    * Basically: do we want to abstract away the platform+machine or just the machine at the IR level?
        * Ideally we'd treat these as separate concerns, but things like windows not having a stable syscall API make this hard to do practically.
    * Yes, you might get less optimal syscalls, but I consider syscalls to be hot lava anyway.
    * Completely abstract away the operating system at compile time :D
    * What about embedded? We shouldn't assume there's an operating system at all...
        * Maybe we need to raise it to the 'malloc' level, not mmap?
    * I think we might want 'generally-portable ops', 'OS-portable ops', 'OS-specific ops', and 'machine code/asm passthrough'
        * Avoid windows OS-specific ops to discourage bad design
    * Might be a problem for win32 if they force us to do stuff at a higher level of abstraction. Windows tends to have some really dumb design decisions.
        * Thus, might still need a passthrough in *addition* to this abstraction layer.
    * How GCC/clang/LLVM land-work:
        * syscalls are all implement in libc-land
        * syscalls are implemented via platform-specific passthrough like asm {}.
    * Honestly, I think I want all three in the IR, there's no harm in it as far as I can tell:
        * fully portable instructions
            * malloc - can be done on AVR etc
                * Would probably be a "simple" allocator that builds directly onto a syscall on platforms like linux. Allocators would use it sparingly, same as the syscall.
        * OS-only portable instructions, don't work on embedded
        * machine-specific instructions, such as assembly/machine language passthrough
            * mmap
        *
        * Just make it really clear in the names: (OS-ONLY/instruction param0 param1)
        * At IR compile time, you choose one of 3 modes: fully portable, OS-only portable, machine-specific.
    * Keep it simple though, don't implement complex features here. We need to implement the IR many times, once per platform.
* Parellelizing macroexpansion should be possible and is possibly a big advantage of doing things this way.
    * If our IR optimizer runs separately per-function, this would thus implicitly paralellize optimization
    * You probably want to be able to choose if you're working on serial or parallel when you call structural_macro_expand. You might care about macroexpansion ordering, you might not. You can choose serial mode in your macro when expanding your child elements if you are for example building an interpreted language with side-effect macros.
        * top-level would be parallel tho. You would need to opt-in to serial expansion.
        * could provide an (bb/serial-expand foo) macro to make this ergonomic.
    * threading overhead might be a waste on tiny macros
        * could allow for hinting to disable the thread queuing and just do it in the main thread
            * "Hi I'm really cheap to expand just do it"
        * could use a heuristic like the size of the macro in bytes, though false positives would suck
        * could even make parallelism opt-in per defined macro if the overhead is really bad.
    * probably task queue/worker model
* I want to maintain a pattern through all abstractions through to high-level that makes it really obvious when you're using something that's not portable to all machines
    * Such as using a 'non-portable' or 'linux-only' namespace.
* I think the IR should always support up to 64-bit integers. Platforms with less than this need to emulate them.
    * For emulation, we probably want to do the lowering within the IR itself so the emulation can be optimized and we only need to implement this once. IR -> IR transformation.
    * Some compilers support extra-big integers like 128-bit. It would be interesting to experiment with this once we have lowering logic in the IR.
        * Would be cool if we could make it width-arbitrary lowering, and support 512-bit integers or whatever.
            * This makes sense because if the width is fixed - even when it's really wide - we can be more optimal than generalized bignums.
* Instead of having noexpand-data, threadlocal-data, threadlocal-noexpand-data, we could have you say (data (noexpand threadlocal) name my-data). Could remain compatible with the (data name my-data) syntax because it's clear there's flags there if it's a parray.
* Note on recursive functions in bb/with
    * bb-time functions/macros are expected to be position-independent. Calling yourself at an absolute address is not position-indepedent.
    * If you want to recurse, you need to call a relative address. To call a relative address, use a label. Hence, to recurse, place a label at the top of your function and call that.
    * We should not support recursion at the bb/with level
        * This is really hard to do, and would need to be done with a trampoline to maintain position-independence in recursive cases.
    * Inter-dependent recursive functions can exist in the same "data" entry calling eachother with labels. This maintains position independence.
* Another argument for macros using absolute pointers:
    * Macros who simply work internally using pure relative pointers and convert everything at the end to absolute with rel-to-abs are doing exactly the same work that we would need to do anyway: before the printer can print something, it needs to know where it is in memory, meaning at some point that pointer is getting converted to absolute either way.
    * The pattern can be clearly documented - build using relative pointers, convert to absolute with rel-to-abs function, return
    * We could probably rewrite some of our existing stuff to use this pattern more
    * Maintains the full flexibility of absolute pointers such as being able to return data in 'with' directly without copying.
    * If macros use absolute pointers, you have a choice: do I want to work in relative or absolute pointers? If macros use relative pointers, you're locked into relative pointers.
