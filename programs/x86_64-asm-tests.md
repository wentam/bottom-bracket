TODO make actual unit tests, maybe look at nasm and others.

* Make sure we always use the smallest possible encoding when using immediate values with various instructions
    * This means 'more desirable' simpler encodings should always be higher in the instruction table, as we scan top-down

* Make sure mov rsi, qword\[rbp\] is encoded correctly as this is a special case
* Make sure mov rsi, qword\[rsp\] is encoded correctly as this is a special case

* tests for labels
