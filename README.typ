#show link: set text(fill: blue)
#show link: underline
#set text(font: "Iosevka NF",
          size: 12pt)
#set page(columns: 1,
          height: auto
          )
#show heading: set block(below: 16pt)
#set heading(numbering: "1.")

#let warning-box(title, body) = block[
  #let warning = [
  #box(fill: rgb("#ff444422"),
       width: 100%,
       radius: (top: 5pt),
       inset: 16pt,
       title)

    #box(inset:(left: 16pt, right: 16pt, bottom: 16pt, top: 4pt), body)
  ]

  #box(radius: (bottom: 5pt),
       fill: rgb("#ff444422"),
       warning)
]

#place(
  top,
  scope: "parent",
  float: true,
  text()[
    #align(center)[
      #v(1cm)

      #text(17pt)[ *[bottom-bracket]* ]

      _What if we didn't assume our abstractions; what if we derived them?_

      #text(10pt)[Matthew Egeler]
    ]

    #v(1cm)

    #text(14pt)[*Abstract*]

    Bottom-bracket (BB) is a homoiconic language designed to express the compilation of anything
    to anything through bottom-up abstraction via macros written in anything.

    It's intended to serve as a minimal top-down to bottom-up abstraction turnaround point at as
    low of a level as possible. It is designed to be as unopinionated as possible.

    This is done with compilation of code to machine language in mind, but it's open-ended.

    Using BB without any libraries, you start at machine language with macros. Programming
    languages are just macro libraries.

    #v(0.5cm)

    #warning-box([
      *Beware: it's not stable yet*
    ], [
      Breaking changes should be expected for now. We need to get the core of the language right,
      and some iteration is inevitable.

      Eventually the hope is to build a stable specification for everyone to implement.

      Such that you're not flying completely blind, here are some anticipated breaking changes:
      - Parallelized macroexpansion where possible
      - Macro I/O details (inputs, return value etc).
      - Changes to parameters and interfaces of builtin functions
      - Changes to which builtin functions are exposed

      This doesn't mean don't build stuff with BB. This means use a pinned version of BB for
      anything you need to stay working, and be ready for migration work.
    ])

    #show outline.entry: it => link(
      it.element.location(),
      it.indented(it.prefix(), it.body()),
    )


    #v(1cm)

    #line(length: 100%) // TODO black in light mode

    #v(1cm)

    #outline(title:none)

    #v(0.5cm)
  ],
)

= Introduction

When we create abstractions, one common approach is to begin with a top-level interface we'd like
to have, and then work down towards the layer below working out how to make it happen. This is
top-down abstraction, and it's the default mode of operation for software development today.

There's another way, though, one pioneered by languages like lisp. Rather than starting from an
ideal interface, we start with what exists now, pick a direction we'd like to go, and start working
our way up towards a particular problem we'd like to solve. The abstraction that we create is
simply the abstraction that logically forms when attempting to move in that direction. This is the
bottom-up approach.

Many areas of science were formed using top-down abstraction by necessity. We made high-level
observations about the world (salt goes away in water!) and created abstractions for those
observations. As we came to understand the underlying mechanisms, the high-level
layer was already established - so we 'make it work' to make our abstractions logically map
together as well as we can. It's never perfect though. This approach lends itself to abstractions
that don't logically map to eachother very cleanly.

By contrast, mathematics has largely evolved in a more bottom-up fashion. Each abstraction is built
upon the previous, and what resulted is a ruthlessly logical and clean system.

These examples illustrate how bottom-up abstraction lends itself to a clean, well-mapped,
less leaky design.

Of course,
#link("https://www.joelonsoftware.com/2002/11/11/the-law-of-leaky-abstractions/",
      "it's never perfect"). Every layer leaks to some degree - even with the bottom-up approach -
and we just work to keep it to a minimum. The benefit of minimizing abstraction leakage is huge,
though: the less each layer leaks, the higher we can stack abstractions without accumulating
frustrating behaviors and performance issues.

Bottom-bracket embraces the bottom-up philosophy. It is built for bottom-up abstraction (enabled by macros)
to minimize abstraction leakage. In contrast to most lisps, it does not start at a high-level of
abstraction, but starts right at the machine-language level.

// TODO talk about how BB also makes it so that you can always build towards the target problem
// from any abstraction in a goo-like way.

= Bottom-bracket's lifecycle: read -> expand macros -> print

That's it! That's the whole thing!

= Language details

== The _default_ syntax

Emphasis on *default* because users of bottom-bracket have control over this through reader and printer
macros.

```lisp
(hello)

```

== The in-memory data structure

=== parray

=== barray

= Bottom-bracket is a minimal core

Implementations of bottom-bracket itself are extremely minimal. The version written in x86_64 assembly
currently sets around 5,000 lines total.

Generally speaking, if it can be done inside the BB language and not as a builtin, it should be.

// TODO no special operators
// TODO limited set of builtin macros that you can re-create yourself.

= What about portability?
// TODO explain how macros are per-arch etc.

= Fully verifiable bootstrap is a goal

= Structure of this repository

- impl     - implementations of bottom-bracket.
- docs     - rendered docs for github pages (not user-facing)
- notes    - almost anything
- programs - misc programs written in BB

// TODO reader and printer macros

// TODO make clear macros can use macros, though you can write your macros with your language
