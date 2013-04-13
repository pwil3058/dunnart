Dunnart D Parser Generator (ddpg)
=================================

Enhanced LALR(1) Parser Generator for the D Programming Language.

This tool is an implementation in D of the LALR(1) parser generators
described in "Compilers - Principles, Techniques and Tools" (Aho, Sethi
and Ullman, 1986) with modifications to allow conflict resolution using
boolean predicates and a built in lexical analyser.  It produces a
single D file as output.

The specification language for dunnart (in itself) is described (in the
specification language for dunnart) in the file dunnart.ddgs which is
used to implement the ddpg program recursively via a three stage
bootstrap process.  In summary:

```
specification: [preamble] definitions "%%" production_rules [coda].
preamble: "%{" <arbitrary D code> "%}".
coda: "%{" <arbitrary D code> "%}".
definitions : [field_definitions] token_definitions [skip_definitions] [precedence_definitions].
field_definitions: {"%field" <field type> <field name> [<conversion function>]}.
token_definitions: {"%token" [<field name>] <token name> <lexical pattern>}.
skip_definitions: {"%skip" <regular expression>}.
precedence_definitions: {("%left"|"%right"|"%nonassoc") <token list>}.
production_rules: {left_hand_side ":" right_hand_side {"|" right_hand_side} "."}.
right_hand_side: [<list of symbols>] ["?(" <predicate> "?)"] ["%prec" <tag>] ["!{" <semantic action D code> "!}"].
```

Like _flex_, the lexical pattern for tokens has two forms:
 1. literal tokens where the text to be matched is placed between double quotes e.g. `"+="`, and
 2. regex tokens where the text to be matched is described by a D std.regex regualar expression
enclosed in parenthesis e.g. `([a-zA-Z][a-zA-Z0-9_]+)`.

Within the production rules, regex tokens are represented by their names and literal tokens are
represented by their names or their pattern (at the programmers option).

See the [wiki pages](http://github.com/pwil3058/dunnart/wiki) for more detail.
