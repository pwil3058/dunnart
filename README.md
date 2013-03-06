dunnart
=======

LALR(1) Parser Generator for the D Programming Language

The primary reason for creating this tool is to become proficient with the
D Programming Language but it is intended that the result will be a usable
parser generator (similar to yacc, llama, bison, hinny, etc.) for D.

It will not be a port of any of the above but will be based on the Honours
Thesis that I wrote when creating hinny (which was an enhanced LALR(1) parser
generator for Modula-2).  However, as it is heavily influenced by the
requirement to spit out Modula-2 code, the grammar specification language for
hinny is not suitable so a language based on bison's will be used in the first
instance.  However, as there will be a clear seperation between the parsing of
specifications and the generation of the parser, it should be possible for
alternative specification languages to be added later.

