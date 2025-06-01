
# Data types

## Semantics

AARRP has two data types, both arrays: parrays (pointer arrays) and barrays (byte arrays).

* parrays are arrays that point to either other parrays or barrays.
* barrays are arrays of untyped bytes.

## Syntax

* Characters placed side-by-side are a barray literal. Hence `foo` represents an
  array of the bytes `102 111 111`.

* parrays are deliminated by ( and ). Hence `(foo bar baz)` represents
  an array of pointers to the barrays `['f','o','o']` `['b','a','r']` and
  `['b','a','z']`.

* "fo(o \xFF \n" is a byte-string with escape codes that also represends a barray

These types can be nested as much as you'd like to produce a tree-like structure:
`(foo bar (biz boz) (((thing))) () blah)` is a valid structure.

## Memory structure

barrays are represented with a size\_t positive length of the array,
followed by a byte for each element, hence the barray `foo` is
`[3,'f','o','o']` in memory.

parrays are represented with a size\_t one's complement length of the
array, followed by size\_t pointers for each element, hence the parray
`(foo bar baz)` is `[-4,*ptr,*ptr,*ptr]` in memory.

Where 'a' is the character encoded number for the letter 'a' (97 in ASCII).

Take note of how the type is defined: A positive length represents a barray
while a negative length represents a parray. This allows you to nest them
to build a tree and know what it is that you've got when it's time to traverse
the tree.

# General notes/ideas

* A defmacro should be able to expand into a defmacro. (or macrolet if we're
  taking that route)
* Make sure macros that produce calls to macros get fully expanded recursively
* We need some kind of -Dthing mechanism to make compile-time defines that can be
  referenced inside macros. Probably define compile-time and run-time archs in
  these variable for macros to reference.
* including another file should be possible with just a macro, as there's
  nothing that says a macro can't perform actions like
  opening a file on the compiling system
* macros should probably specify what platforms they support so we can
  generate nice errors if you use a macro on an unsupported platform
* We should support adding arbitrary data/files to .rodata and .data at compile
  time, including data read in via the reader.
* What if instead of specifying textual instructions, the user specified
  hex opcodes at the top level? The 'mov' macro could then implement that
  behavior via the opcodes of the relevant platform.
* macros need to be able to use macros
* probably support something like nasm's local labels ('.' prefix)
* macros can output arrays of not just text, but arbitrary binary
* built-in macros implement the language and ultimately expand to a
  single array of bytes to be outputted to the file/stdout/whatever
* the above means that compiling a BB program doesn't need to actually
  produce a compiled program, but any output you please
  (text file?).
* We may need a syntax that will cause the reader to error out - like lisp's
  < and >. This would allow the printer to write out binary bytes as hex-literals.
* because macros can output arbitrary bytes as array elements, macros can
  implement hex literals
* example programs to provide: hello world, macroexpansion html generator, writing
  in machine language via hex literals, a macro who's output depends on user input at
  build time (via stdin? gui?), producing a binary file with the printer by
  disabling the byte-string syntax then reading it back in with the reader by
  changing the reader rules
* There is nothing special about 'asm'. Macros are not defined in terms of
  assembly, but machine code. 'asm' is just a macro that resolves to a barray
  of machine code.
* 'asm' should probably be broken down into something more specific - such as
  `(x86\_64-elf-asm (code))` - or ideally `(elf (section .text (x86\_64-asm (code))))` if
  those concerns can be separated
* [ and ] could be a 'flat array' (farray) where byte arrays are placed flat
  in the array instead of as pointers
* macroexpander macros?
* more types could be added by using another bit from -length things.
  this works because if your children are 8-bytes each you can lose the
  extra space and still be able to fill all memory.
* Make comments a fundamental datatype?

# Problems to think about

## numeric literals in arrays are a problem

With the current design, the array (1 2 3 4) is not the numbers [1,2,3,4] bit
an array with the chars ['1', '2','3','4']. This would neccesitate languages
to have their own (make-array '(1 2 3 4)) to actually get a numeric array.

This is confusing - as a homoiconic language we want you to be able to actually
use the built-in datatype as part of the language.

This is tricky, though: what if you wanted to implement a bignum library and
have bignums in the array? what width are the integers? We exist at too low of
a level to make these decisions.

I think reader macros are the answer, much like with string issues:
a reader macro can find number literals and wrap them up as (number 5) for
example.

## non-special parenthesis

You're making a string library. You create a function/macro that creates
a string from a literal and returns a pointer to it.

The function is called with the following argument:

(make-string "aoeu)oeueo")

As far as the reader is concerned, this is the array (make-string "aoeu) with
the invalid text oeueo") after it.

This is because by our language specified thus far, we're not aware of
quoted strings as a data type.

Escape character mechanism are possible, but confusing because you'd be escaping
for the expression and not for the string. Perhaps with a different char than '\'
it would be less confusing: (make-string "aoeu$)oeueo")

Sure, the language could support string literals, but this isn't just about
strings as it represents an inherent inflexibility in the metaprogramming
design.

# TODO

* reader macros
* printer macros?
* symbol macros
* sections?
* need a way to define functions available to macros at macroexpand/compile time
* byte strings syntax
* the reader and printer should be defined entirely through reader and printer
  macros - such that the user can replace the behavior entirely should they choose.

TODO: we've been assuming the array deliminators are '(' and ')'. Could we
instead allow the user to choose what chars they want at compile time?
('[' and ']' if they so please.)
