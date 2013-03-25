module bespoke;

import std.stdio;

import symbols;
import grammar;

import ddlib.lexan;

SymbolTable bespokeSymbolTable;
GrammarSpecification bespokeGrammarSpecification;
auto bespokeSkipPatterns = [r"(/\*(.|[\n\r])*?\*/)", r"(//[^\n\r]*)", r"(\s+)"];
LexicalAnalyser bespokeLexAn;
Grammar bespokeGrammar;

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
    with (bespokeSymbolTable) with (bespokeGrammarSpecification) {
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
        auto VBAR = new_token("VBAR", "\"|\"", plf.next(true));
        auto IDENT = new_token("IDENT", r"([a-zA-Z]+[a-zA-Z0-9_]*)", plf.next(true));
        auto FIELDNAME = new_token("FIELDNAME", r"(<[a-zA-Z]+[a-zA-Z0-9_]*>)", plf.next(true));
        auto PREDICATE = new_token("PREDICATE", r"(\?\((.|[\n\r])*?\?\))", plf.next(true));
        auto ACTION = new_token("ACTION", r"(!\{(.|[\n\r])*?!\})", plf.next(true));
        auto DCODE = new_token("DCODE", r"(%\{(.|[\n\r])*?%\})", plf.next(true));
        bespokeLexAn = new LexicalAnalyser(generate_lexan_token_specs(), bespokeSkipPatterns);

    // Rules specification
        auto specification = define_non_terminal("specification", plf.next(true));
        auto preamble = get_symbol("preamble", plf.next(), true);
        auto definitions = get_symbol("definitions", plf.next(), true);
        NEWSECTION = get_literal_token("\"%%\"", plf.next()); // adds to the "used at" data
        auto production_rules = get_symbol("production_rules", plf.next(), true);
        add_production(new Production(specification, [preamble, definitions, NEWSECTION, production_rules], "// that's all folks"));

        auto allowable_ident = define_non_terminal("allowable_ident", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next());
        add_production(new Production(allowable_ident, [IDENT], "// check ident name"));

    //Preamble
        preamble = define_non_terminal("preamble", plf.next(true));
        DCODE = get_symbol("DCODE", plf.next(true));
        add_production(new Production(preamble, [], "// do nothing"));
        add_production(new Production(preamble, [DCODE], "// save code for copying to generated parser module"));

    //Definitions
        definitions = define_non_terminal("definitions", plf.next(true));
        auto field_definitions = get_symbol("field_definitions", plf.next(), true);
        auto token_definitions = get_symbol("token_definitions", plf.next(), true);
        auto skip_definitions = get_symbol("skip_definitions", plf.next(), true);
        auto precedence_definitions = get_symbol("precedence_definitions", plf.next(), true);
        add_production(new Production(definitions, [field_definitions, token_definitions, skip_definitions, precedence_definitions], "// do any checks deemed prudent"));

        field_definitions = define_non_terminal("field_definitions", plf.next(true));
        auto field_definition = get_symbol("field_definition", plf.next(true), true);
        add_production(new Production(field_definitions, [], "// do nothing"));
        add_production(new Production(field_definitions, [field_definitions, field_definition], "// do nothing"));

        token_definitions = define_non_terminal("token_definitions", plf.next(true));
        auto token_definition = get_symbol("token_definition", plf.next(true), true);
        add_production(new Production(token_definitions, [], "// do nothing"));
        add_production(new Production(token_definitions, [token_definitions, token_definition], "// do nothing"));

        skip_definitions = define_non_terminal("skip_definitions", plf.next(true));
        auto skip_definition = get_symbol("skip_definition", plf.next(true), true);
        add_production(new Production(skip_definitions, [], "// do nothing"));
        add_production(new Production(skip_definitions, [skip_definitions, skip_definition], "// do nothing"));

        precedence_definitions = define_non_terminal("precedence_definitions", plf.next(true));
        auto precedence_definition = get_symbol("precedence_definition", plf.next(true), true);
        add_production(new Production(precedence_definitions, [], "// do nothing"));
        add_production(new Production(precedence_definitions, [precedence_definitions, precedence_definition], "// decrement precedence"));

        field_definition = define_non_terminal("field_definition", plf.next(true));
        FIELD = get_literal_token("\"%field\"", plf.next());
        auto field_type = get_symbol("field_type", plf.next(true), true);
        auto field_name = get_symbol("field_name", plf.next(true), true);
        auto field_conversion_function = get_symbol("field_conversion_function", plf.next(true), true);
        add_production(new Production(field_definition, [FIELD, field_type, field_name], "// add field definition to symbol table"));
        add_production(new Production(field_definition, [FIELD, field_type, field_name, field_conversion_function], "// add field definition (and conversion function) to symbol table"));

        field_type = define_non_terminal("field_type", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(field_type, [allowable_ident], "// do nothing"));

        field_name = define_non_terminal("field_name", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(field_name, [allowable_ident], "// do nothing"));

        field_conversion_function = define_non_terminal("field_conversion_function", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(field_conversion_function, [allowable_ident], "// do nothing"));

        token_definition = define_non_terminal("token_definition", plf.next(true));
        TOKEN = get_literal_token("\"%token\"", plf.next());
        FIELDNAME = get_symbol("FIELDNAME", plf.next());
        LITERAL = get_symbol("LITERAL", plf.next());
        REGEX = get_symbol("REGEX", plf.next());
        auto token_name = get_symbol("token_name", plf.next(true), true);
        add_production(new Production(token_definition, [TOKEN, token_name, LITERAL], "// add literal token definition to symbol table"));
        add_production(new Production(token_definition, [TOKEN, token_name, REGEX], "// add regex token definition to symbol table"));
        add_production(new Production(token_definition, [TOKEN, FIELDNAME, token_name, REGEX], "// add regex token definition (with filed name) to symbol table"));

        token_name = define_non_terminal("token_name", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(token_name, [allowable_ident], "// check token not already defined"));

        skip_definition = define_non_terminal("skip_definition", plf.next(true));
        SKIP = get_literal_token("\"%skip\"", plf.next());
        REGEX = get_symbol("REGEX", plf.next());
        add_production(new Production(skip_definition, [SKIP, REGEX], "// add regex to skip list"));

        precedence_definition = define_non_terminal("precedence_definition", plf.next(true));
        LEFT = get_literal_token("\"%left\"", plf.next());
        RIGHT = get_literal_token("\"%right\"", plf.next());
        NONASSOC = get_literal_token("\"%nonassoc\"", plf.next());
        auto tag_list = get_symbol("tag_list", plf.next(true), true);
        add_production(new Production(precedence_definition, [LEFT, tag_list], "// set left associativity"));
        add_production(new Production(precedence_definition, [RIGHT, tag_list], "// set right associativity"));
        add_production(new Production(precedence_definition, [NONASSOC, tag_list], "// set non associativity"));

        tag_list = define_non_terminal("tag_list", plf.next(true));
        auto tag = get_symbol("tag", plf.next(true), true);
        add_production(new Production(tag_list, [tag], "// initialize a dynamic array with [tag]"));
        add_production(new Production(tag_list, [tag_list, tag], "// append to the tag list"));

        tag = define_non_terminal("tag", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(tag, [allowable_ident], "// if not a defined token define it as a non token tag"));

    // Rules defining rules
        production_rules = define_non_terminal("production_rules", plf.next(true));
        auto production_group = get_symbol("production_group", plf.next(true), true);
        add_production(new Production(production_rules, [production_group], "// initialize a dynamic array with [production_group]"));
        add_production(new Production(production_rules, [production_rules, production_group], "// append to the production_group list"));

        production_group = define_non_terminal("production_group", plf.next(true));
        auto production_group_head = get_symbol("production_group_head", plf.next(true), true);
        auto production_tail_list = get_symbol("production_tail_list", plf.next(true), true);
        DOT = get_literal_token("\".\"", plf.next());
        add_production(new Production(production_group, [production_group_head, production_tail_list, DOT], "// add the productions to the grammar specification"));

        production_group_head = define_non_terminal("production_group_head", plf.next(true));
        COLON = get_literal_token("\":\"", plf.next());
        auto left_hand_side = get_symbol("left_hand_side", plf.next(true), true);
        add_production(new Production(production_group_head, [left_hand_side, COLON], "// define the non terminal symbol"));

        left_hand_side = define_non_terminal("left_hand_side", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(left_hand_side, [allowable_ident], "// do nothing"));

        production_tail_list = define_non_terminal("production_tail_list", plf.next(true));
        auto production_tail = get_symbol("production_tail", plf.next(true), true);
        VBAR = get_literal_token("\"|\"", plf.next());
        add_production(new Production(production_tail_list, [production_tail], "// initialize a dynamic array with [production_tail]"));
        add_production(new Production(production_tail_list, [production_tail_list, VBAR, production_tail], "// append to the production_tail list"));

        production_tail = define_non_terminal("production_tail", plf.next(true));
        auto symbol_list = get_symbol("symbol_list", plf.next(), true);
        auto tagged_precedence = get_symbol("tagged_precedence", plf.next(), true);
        PREDICATE = get_symbol("PREDICATE", plf.next());
        ACTION = get_symbol("ACTION", plf.next());
        add_production(new Production(production_tail, [ACTION], "// create empty production"));
        add_production(new Production(production_tail, [symbol_list, PREDICATE, tagged_precedence, ACTION], "// create production"));
        add_production(new Production(production_tail, [symbol_list, PREDICATE, tagged_precedence], "// create production"));
        add_production(new Production(production_tail, [symbol_list, PREDICATE, ACTION], "// create production"));
        add_production(new Production(production_tail, [symbol_list, PREDICATE], "// create production"));
        add_production(new Production(production_tail, [symbol_list, tagged_precedence, ACTION], "// create production"));
        add_production(new Production(production_tail, [symbol_list, tagged_precedence], "// create production"));
        add_production(new Production(production_tail, [symbol_list, ACTION], "// create production"));
        add_production(new Production(production_tail, [symbol_list], "// create production"));

        tagged_precedence = define_non_terminal("tagged_precedence", plf.next(true));
        PRECEDENCE = get_literal_token("\"%prec\"", plf.next());
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        add_production(new Production(tagged_precedence, [PRECEDENCE, allowable_ident], "// get the precedence for the tag"));

        symbol_list = define_non_terminal("symbol_list", plf.next(true));
        auto symbol = get_symbol("symbol", plf.next(true), true);
        add_production(new Production(symbol_list, [symbol], "// initialize a dynamic array with [symbol]"));
        add_production(new Production(symbol_list, [symbol_list, symbol], "// append to the symbol list"));

        symbol = define_non_terminal("symbol", plf.next(true));
        allowable_ident = get_symbol("allowable_ident", plf.next(true));
        ERROR = get_literal_token("\"%error\"", plf.next());
        LEXERROR = get_literal_token("\"%lexerror\"", plf.next());
        add_production(new Production(symbol, [allowable_ident], "// retrieve the named symbol"));
        add_production(new Production(symbol, [ERROR], "// retrieve the named symbol"));
        add_production(new Production(symbol, [LEXERROR], "// retrieve the named symbol"));
    }
    debug(Grammar) {
        foreach (symbol; bespokeSymbolTable.get_undefined_symbols()) {
            writefln("Non terminal: %s is not defined", symbol.name);
        }
    }
    assert(bespokeSymbolTable.count_undefined_symbols() == 0);
    debug(Grammar) {
        foreach (symbol; bespokeSymbolTable.get_unused_symbols()) {
            writefln("Symbol: %s is not used", symbol.name);
        }
    }
    // The start symbol will show up as unused
    assert(bespokeSymbolTable.count_unused_symbols() == 1);
    bespokeGrammar = new Grammar(bespokeGrammarSpecification);
}

void
main()
{
    foreach (line; bespokeGrammar.generate_goto_table_code_text()) {
        writeln(line);
    }
    foreach (line; bespokeGrammar.generate_action_table_code_text()) {
        writeln(line);
    }
}
