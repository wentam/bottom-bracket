Here's some stuff to write out better and put into the README (copy/pasted from
chat w/ andy):

Let me put it this way: most compilers are the top down approach: you design
your target abstraction then work down to the hardware.

The purpose of AARRP is to turn it around to start the bottom-up part of the
stack, which tends to create abstractions that map better to the abstraction
below and is far more modular

Anything outside of the scope of turning it around from "top-down" to
"bottom-up" is outside of the scope of AARRP

AARP is direction reversal right at the assembly layer

bottom-up abstractions also tend to drive you towards less leaky abstractions
because you're writing it in terms of the layer below

This explains why it's such a thin abstraction without even variables: it's
because it's the turnaround point, and turning around is the *entire scope* of
the thing

thin top-down abstractions like C that are very aware of how things work at the
layer below are OK, but that's because C is basically the bottom-up mentality
implemented in a top-down way

common lisp turns this around halfway up the stack, which creates pain when
you care about what happens below the turnaround point - such as when trying
to write fast code. The only way to ensure you never need to cross the
turnaround point is to place the turnaround point lower in the stack than a
developer ever needs to go.
