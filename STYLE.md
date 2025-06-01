For code written in bottom-bracket in this repo:

* Indent with 1 space (ASCII 0x20 only)
    * Plenty enough to make nesting visible.
    * Minimizes column waste.
    * Just look at the column number in your text editor
      and you know the nesting level
* No tabs for anything ever
    * Tabs make alignment across different editors with different
      tab widths impossible.
    * Tabs make it impossible to have the same column limit across editors, as the text will be wider on some than others.
    * Multiple invisible character types creates ambiguity
* Align stuff as needed depending on the semantics of
  the macro in use
* Use < 100 columns
    * Some files where this is impractical may choose to be "double wide" and use < 200 columns. Try to avoid this. Make note of this usage in comments at the top of the file.
