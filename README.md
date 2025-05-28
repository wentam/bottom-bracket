# ARRP (ARRay Processing)

ARRP is a homoiconic language designed to express the compilation of anything
to anything through bottom-up abstraction via macros written in anything.

It's intended to serve as a minimal top-down to bottom-up abstraction turnaround point at as low of a level as possible, and be as unopinionated as possible.

This is done with compilation of code to machine language in mind, but it's open-ended.

# Beware: it's not stable yet

Breaking changes should be expected for now. We need to get the core of the language right, and some iteration is inevitable.

Eventually the hope is to build a stable specification for everyone to implement.

Such that you're not flying completely blind, here are some anticipated breaking changes:
* Parallelized macroexpansion where possible
* Macro I/O details (inputs, return value etc).
* Changes to parameters and interfaces of builtin functions
* Changes to which builtin functions are exposed

This doesn't mean don't build stuff with arrp. This means use a pinned version of arrp for anything you need to stay working, and be ready for migration work.
