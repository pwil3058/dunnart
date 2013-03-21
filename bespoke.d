module bespoke;

import symbols;
import grammar;

import ddlib.lexan;

SymbolTable bespokeSymbolTable;
GrammarSpecification bespokeGrammarSpecification;
auto bespokeSkipPatterns = [r"(/\*(.|[\n\r])*?\*/)", r"(//[^\n\r]*)", r"(\s+)"];
LexicalAnalyser bespokeLexAn;

class PhonyLocationFactory {
    size_t lineNumber;
    size_t offset;

    this() {
        lineNumber = 0;
    }

    void
    incr_line()
    {
        lineNumber++;
        offset = 0;
    }

    CharLocation
    next(bool incrLine=false)
    {
        if (incrLine) {
            incr_line();
        }
        return CharLocation(lineNumber, offset++);
    }
}

static this() {
    auto plf = new PhonyLocationFactory;
    bespokeSymbolTable = new SymbolTable;
    bespokeGrammarSpecification = new GrammarSpecification(bespokeSymbolTable);
    with (bespokeSymbolTable) {
        auto REGEX = new_token("REGEX", r"(\(\S+\))", plf.next(true));
        auto LITERAL = new_token("LITERAL", "(\"\\S+\")", plf.next(true));
        auto TOKEN = new_token("TOKEN", "\"%token\"", plf.next(true));
        auto FIELD = new_token("FIELD", "\"%field\"", plf.next(true));
        auto LEFT = new_token("LEFT", "\"%left\"", plf.next(true));
        auto RIGHT = new_token("RIGHT", "\"%right\"", plf.next(true));
        auto NONASSOC = new_token("NONASSOC", "\"%nonassoc\"", plf.next(true));
        auto PRECEDENCE = new_token("PRECEDENCE", "\"%prec\"", plf.next(true));
        auto SKIP = new_token("SKIP", "\"%skip\"", plf.next(true));
        auto ERROR = new_token("ERROR", "\"%error\"", plf.next(true));
        auto LEXERROR = new_token("LEXERROR", "\"%lexerror\"", plf.next(true));
        auto NEWSECTION = new_token("NEWSECTION", "\"%%\"", plf.next(true));
        auto COLON = new_token("COLON", "\":\"", plf.next(true));
        auto DOT = new_token("DOT", "\".\"", plf.next(true));
        auto IDENT = new_token("IDENT", r"([a-zA-Z]+[a-zA-Z0-9_]*)", plf.next(true));
        auto FIELDNAME = new_token("FIELDNAME", r"(<[a-zA-Z]+[a-zA-Z0-9_]*>)", plf.next(true));
        auto ACTION = new_token("ACTION", r"(!\{(.|[\n\r])*?!\})", plf.next(true));
        auto DCODE = new_token("DCODE", r"(%\{(.|[\n\r])*?%\})", plf.next(true));
        bespokeLexAn = new LexicalAnalyser(generate_lexan_token_specs(), bespokeSkipPatterns);

        auto specification = define_non_terminal("specification", plf.next(true));
        auto preamble = get_symbol("preamble", plf.next(), true);
        auto definitions = get_symbol("definitions", plf.next(), true);
        NEWSECTION = get_literal_token("\"%%\"", plf.next()); // adds to the "used at" data
        auto production_rules = get_symbol("production_rules", plf.next(), true);
        bespokeGrammarSpecification.add_production(new Production(specification, [preamble, definitions, NEWSECTION, production_rules]));

        auto allowable_ident = define_non_terminal("allowable_ident", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next()); // adds to the "used at" data
        bespokeGrammarSpecification.add_production(new Production(allowable_ident, [IDENT]));
    }
}
