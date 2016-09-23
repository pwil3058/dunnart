Dunnart D Parser Generator (ddpg)
=================================

Enhanced LALR(1) Parser Generator for the D Programming Language.

This (ddgp) tool is an implementation in D of the LALR(1) parser generators
described in "Compilers - Principles, Techniques and Tools" (Aho, Sethi
and Ullman, 1986) (aka the red dragon book) with modifications to allow
conflict resolution using boolean predicates and a built in lexical
analyser.  It produces a single D file as output.

The [specification language](https://github.com/pwil3058/dunnart/wiki/Specification-Language)
for dunnart (in itself) is described (in the
specification language for dunnart) in the file dunnart.ddgs which was
used to implement the ddpg program recursively via a three stage
bootstrap process (one stage now permanently retired).

Building ddgp
=============

To build __ddgp__ execute the following:
```
$ make
```
in the base directory.

Synopsis
========
```
ddgp [<options>] <specification file name>
Options:
    -f|--force:
        overwrite existing output file
    -m <name> | --module=<name>:
        insert a "module" statement in the output file using name
    -v|--verbose:
        produce a full description of the grammar generated
    -o <name>|output=<name:
        write the generated parser code to the named file
    -p <path>|--prefix=<path>:
        if using a path name based on the module name prefix it with path
    -e  <number>|expect=<number>:
        expect exactly "number" total conflicts
```

Output File Name
================
If the _--module_ option is used the output filename will be derived
from the module name (prefixed with the argument to the _--prefix_
option if present) unless it is overruled by the _--output_ option.
If neither the _--module_ nor _--output_ option are present, the output
filename will be constructed by replacing the input filename's suffix
with "d".

In no event, will an existing file be overwritten unless the _--force_
option is used.

License
=======
Dunnart D Parser Generator (ddpg) is licensed under the Boost Software
License, Version 1.0. (See accompanying file LICENSE_1_0.txt or
[copy at](http://www.boost.org/LICENSE_1_0.txt)).
