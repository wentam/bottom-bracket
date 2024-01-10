# TODO

* reader macros
* symbol macros
* sections?
* array data type option 3: pointery. Probably doing it this way.
* need a way to define functions available to macros at macroexpand/compile time

TODO: we've been assuming the array deliminators are '(' and ')'. Could we
instead allow the user to choose what chars they want at compile time?
('[' and ']' if they so please.)

# Array data type option 1

## Semantics

The base data type is an array whose elements are either another array or a
single character.

TODO: define character: is it ASCII? 8-byte unicode? Defined by user at build
time? Note: we really only care about the integer size backing the character and
which integers represent '(' and ')' or whatever our array deliminators are.

* Characters placed side-by-side are simple a shorthand for an array contains
  those chars.

  hence:
  (foo bar baz) is equivelent to ((f o o) (b a r) (b a z))

* Double quotes or numbers at this level would have no special meaning.

  hence:
  "foo" == (" f o o ").
  5 is just the character 5 (ASCII code 53)

  The only characters with special meaning are ( and ).

## Memory structure

Arrays are represented without any pointers as follows:

(f o o): [3, -1, 'f', -1, 'o', -1, 'o']
((a b c) (d e f)): [2, 3, -1, 'a', -1, 'b', -1, 'c', 3, -1, 'd', -1, 'e', -1, 'f']

Where 'a' is the character encoded number for the letter 'a' (97 in ASCII).

A positive number represents the length of the following array while -1
represents that the following item is a character.

Optimization that may or may not be worth the extra confusion: -2 could
represent that the next two things are characters.

TODO: how large can the array length be? fixed? leb128? If fixed size, we
      should used INT-MAX instead of -1 to represent that the following is a
      character as this is more efficient than a signed integer.

# Array data type option 2

## Semantics

The base data type is an array whose elements are either another array or an
atom.

TODO: define character: is it ASCII? 8-byte unicode? Defined by user at build
time? Note: we really only care about the integer size backing the character and
which integers represent '(' and ')' or whatever our array deliminators are.

* Characters placed side-by-side are an atom.

  hence:
  (foo bar baz) != ((f o o) (b a r) (b a z))

* double quotes or numbers at this level would have no special meaning.

  hence:
  "foo" is the literal string "\"foo\""
  5 is the string "5"

  The only characters with special meaning are ( and )

## Memory structure

Arrays are represented without any pointers as follows:

(foo): [1, -3, 'f', 'o', 'o']
(foo four): [2, -3, 'f', 'o', 'o', -4, 'f', 'o', 'u', 'r']
(foo (bar baz)): [2, -3, 'f', 'o', 'o', 2, -3, 'b', 'a', 'r', -3, 'b', 'a', 'z']

Where 'a' is the character encoded number for the letter 'a' (97 in ASCII).

A positive number represents the length of the following array while negative
lengths represent the length of the string.

# Array data type option 3

## Semantics

The base data type is an array whose elements are either another array or an
atom.

TODO: define character: is it ASCII? 8-byte unicode? Defined by user at build
time? Note: we really only care about the integer size backing the character and
which integers represent '(' and ')' or whatever our array deliminators are.

* Characters placed side-by-side are an atom (the smallest type of object with
  no other type composing it)

  hence:
  (foo bar baz) != ((f o o) (b a r) (b a z))

* double quotes or numbers at this level would have no special meaning.

  hence:
  "foo" is the literal string "\"foo\""
  5 is the string "5"

  The only characters with special meaning are ( and )

## Memory structure

Arrays are represented without any pointers as follows:

(foo): [1, -3, 'f', 'o', 'o']
(foo four): [2, -3, 'f', 'o', 'o', -4, 'f', 'o', 'u', 'r']
(foo (bar baz)): [2, -3, 'f', 'o', 'o', 2, -3, 'b', 'a', 'r', -3, 'b', 'a', 'z']

Where 'a' is the character encoded number for the letter 'a' (97 in ASCII).

A positive number represents the length of the following array while negative
lengths represent the length of the string.

## TODO: how large can the array and atom lengths be? fixed? leb128?

* leb128 would require macro-writers to have the tools available to decode
  leb128, probably in the form of a function available at compile-time in the
  macro. If you have such a function, what does that function output? In the
  end, it always needs to live in a register, and 8-bit might be the largest
  register you have.
* using anything larger than an 8-bit integer for these values starts to make
  things more difficult on different architectures. Consider 8-bit AVR.
* an 8-bit integer is definitely too limiting for this. (example: you could
  only have 255 lines of code at the top level)
* This distinction only matters at compile time, so it's probably safe to
  assume you have access to at least a 32-bit register even if you're
  compiling for AVR (I don't see a need to run the compiler on AVR :P)
* We could completely dodge this issue by instead making all strings and arrays
  NULL-terminated.
* We could dodge this issue by having lengths specified as 1-byte integers
  where if the length is 255 you must read the next and add it together.

# General questions

## Should the bootstrapping compiler be written in assembly? C?
* Writing in C is more portable than writing in X86\_64-linux assembly. Writing
  in assembly means you need to explicitly write the entire compiler for each
  platform that you want to be able to bootstrap a compiler on.
* When writing in C you could output to .asm files and keep them in-repo.

## Should calling conventions for macros follow the OS around, or should all x86\_64 macros use linux convention?

## Should macros expand text<->text before the reader or array<->array after the reader?

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
