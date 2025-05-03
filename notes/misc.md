Keep these notes around even after stuff is implemented so I can remember why I did things! I often forget.

Try to re-read this occassionaly when working on aarrp so we remember important things.

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
  ((elf64-relocatable
     (x86_64-linux (cat
                     "some machine code" ; mov rdi, 5
                     "some machine code" ; syscall
                     "some machine code")))
   (nest
     (x86_64-linux (cat "foo" "bar"))
     (aarch64-windows (cat "foo" "bar"))))

  (elf64_relocatable foo))

Currently strongly leaning towards resolving it within aarrp. Avoids undefined behavior, can easily emit a warning if you define a macro without an implementation for the aarrp execution platform, can easily emit an error when you try to call a macro when there isn't an implementation for the aarrp execution platform, more ergonomic, doesn't really add complexity to aarrp (but would be a bit complex to do it inside the aarrp language), completely thetical to aarrp's role as managing the execution of machine-language macros. Implementing this yourself inside the aarrp language would *not* allow you to produce a nice error upon macroexpansion, so I think this is a must.

Question is: is this by cpu arch? x86_64, arm? or By platform: x86_64-linux, arm-windows. My current intuition says platform: I think you want a separate entry to occur per implementation required - which itself is a good way to define "platform" within aarrp. Windows and linux have different "system" apis, linux with syscalls and windows with win32, and this demands separate implementations.

This does result in a combinatorial explosion of assemblers required to be implemented in machine language inside the aarrp language, but I think that's just reality.
* To bootstrap aarrp, we could implement it once in as simple of an assembly language as possible - like RISC-V - then demand that those who wish to bootstrap must run a RISC-V virtual machine. If you keep it to a minimal portion of the risc-V instruction set, said VM could be very simple. We could even write some VMs.
