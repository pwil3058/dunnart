// bespoke.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module bespoke;

import std.stdio;
import std.file;
import std.getopt;

import symbols;
import grammar;

import ddlib.lexan;

SymbolTable bespokeSymbolTable;
GrammarSpecification bespokeGrammarSpecification;
LexicalAnalyser bespokeLexAn;
Grammar bespokeGrammar;

class PhonyLocationFactory {
    size_t lineNumber;
    size_t offset;

    this()
    {
        lineNumber = 0;
    }

    void incr_line()
    {
        lineNumber++;
        offset = 0;
    }

    CharLocation next(bool incrLine=false)
    {
        if (incrLine) {
            incr_line();
        }
        return CharLocation(lineNumber, offset++);
    }
}

auto verbose = false;

auto bespokePreamble =
"import std.stdio;

import symbols;
import grammar;

SymbolTable symbolTable;
GrammarSpecification grammarSpecification;

static this () {
    symbolTable = new SymbolTable;
    grammarSpecification = new GrammarSpecification(symbolTable);
}

struct AssociatedPrecedence {
    Associativity associativity;
    Precedence    precedence;
}

struct ProductionTail {
    Symbol[] rightHandSide;
    AssociatedPrecedence associatedPrecedence;
    Predicate predicate;
    SemanticAction action;
}

// Aliases for use in field definitions
alias ProductionTail[] ProductionTailList;
alias Symbol[] SymbolList;
alias string[] StringList;

uint errorCount;
uint warningCount;\n";

void generate_grammar()
{
    auto plf = new PhonyLocationFactory;
    bespokeSymbolTable = new SymbolTable;
    bespokeGrammarSpecification = new GrammarSpecification(bespokeSymbolTable);
    with (bespokeSymbolTable) with (bespokeGrammarSpecification) {
        set_preamble(bespokePreamble);
        new_field("stringList", "StringList");
        new_field("productionTailList", "ProductionTailList");
        new_field("productionTail", "ProductionTail");
        new_field("symbolList", "SymbolList");
        new_field("symbol", "Symbol");
        new_field("predicate", "Predicate");
        new_field("semanticAction", "SemanticAction");
        new_field("associatedPrecedence", "AssociatedPrecedence");
        auto REGEX = new_token("REGEX", r"(\(.+\)(?=\s))", plf.next(true));
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

        add_skip_rule(r"(/\*(.|[\n\r])*?\*/)"); // D style comments
        add_skip_rule(r"(//[^\n\r]*)"); // D EOL style comments
        add_skip_rule(r"(\s+)"); // White space

    // Simulate use of "specification" in grammar augmentation
        auto specification = get_symbol("specification", plf.next(), true);
    // Rules specification
        specification = define_non_terminal("specification", plf.next(true));
        auto preamble = get_symbol("preamble", plf.next(), true);
        auto definitions = get_symbol("definitions", plf.next(), true);
        NEWSECTION = get_literal_token("\"%%\"", plf.next()); // adds to the "used at" data
        auto production_rules = get_symbol("production_rules", plf.next(), true);
        add_production(new Production(specification, [preamble, definitions, NEWSECTION, production_rules], "// that's all folks"));

    //Preamble
        preamble = define_non_terminal("preamble", plf.next(true));
        DCODE = get_symbol("DCODE", plf.next(true));
        add_production(new Production(preamble, [], "// do nothing"));
        add_production(new Production(preamble, [DCODE], "grammarSpecification.set_preamble($1.ddMatchedText);"));

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
        add_production(new Production(token_definitions, [token_definition], "// do nothing"));
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
        add_production(new Production(field_definition, [FIELD, field_type, field_name], "symbolTable.new_field($3.ddMatchedText, $2.ddMatchedText);"));
        add_production(new Production(field_definition, [FIELD, field_type, field_name, field_conversion_function], "symbolTable.new_field($3.ddMatchedText, $2.ddMatchedText, $4.ddMatchedText);"));

        field_type = define_non_terminal("field_type", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        add_production(new Production(field_type, [IDENT], "// do nothing"));

        field_name = define_non_terminal("field_name", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        add_production(new Production(field_name, [IDENT],
            "if (!is_allowable_name($1.ddMatchedText)) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Illegal field name.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "}\n"
             ));

        field_conversion_function = define_non_terminal("field_conversion_function", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        add_production(new Production(field_conversion_function, [IDENT],
            "if (!is_allowable_name($1.ddMatchedText)) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Illegal field conversion function name.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "}\n"
             ));

        token_definition = define_non_terminal("token_definition", plf.next(true));
        TOKEN = get_literal_token("\"%token\"", plf.next());
        FIELDNAME = get_symbol("FIELDNAME", plf.next());
        LITERAL = get_symbol("LITERAL", plf.next());
        REGEX = get_symbol("REGEX", plf.next());
        auto token_name = get_symbol("token_name", plf.next(true), true);
        add_production(new Production(token_definition, [TOKEN, token_name, LITERAL], "symbolTable.new_token($2.ddMatchedText, $3.ddMatchedText, $2.ddLocation);"));
        add_production(new Production(token_definition, [TOKEN, token_name, REGEX], "symbolTable.new_token($2.ddMatchedText, $3.ddMatchedText, $2.ddLocation);"));
        add_production(new Production(token_definition, [TOKEN, FIELDNAME, token_name, REGEX], "symbolTable.new_token($3.ddMatchedText, $4.ddMatchedText, $3.ddLocation, $2.ddMatchedText[1 .. $ - 1]);"));

        token_name = define_non_terminal("token_name", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        add_production(new Production(token_name, [IDENT],
            "if (!is_allowable_name($1.ddMatchedText)) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Illegal token name.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "}\n"
             ));

        skip_definition = define_non_terminal("skip_definition", plf.next(true));
        SKIP = get_literal_token("\"%skip\"", plf.next());
        REGEX = get_symbol("REGEX", plf.next());
        add_production(new Production(skip_definition, [SKIP, REGEX], "symbolTable.add_skip_rule($2.ddMatchedText);"));

        precedence_definition = define_non_terminal("precedence_definition", plf.next(true));
        LEFT = get_literal_token("\"%left\"", plf.next());
        RIGHT = get_literal_token("\"%right\"", plf.next());
        NONASSOC = get_literal_token("\"%nonassoc\"", plf.next());
        auto tag_list = get_symbol("tag_list", plf.next(true), true);
        add_production(new Production(precedence_definition, [LEFT, tag_list], "symbolTable.set_precedences(Associativity.left, $2.symbolList);"));
        add_production(new Production(precedence_definition, [RIGHT, tag_list], "symbolTable.set_precedences(Associativity.right, $2.symbolList);"));
        add_production(new Production(precedence_definition, [NONASSOC, tag_list], "symbolTable.set_precedences(Associativity.nonassoc, $2.symbolList);"));

        tag_list = define_non_terminal("tag_list", plf.next(true));
        auto tag = get_symbol("tag", plf.next(true), true);
        add_production(new Production(tag_list, [tag], "$$.symbolList = [$1.symbol];"));
        add_production(new Production(tag_list, [tag_list, tag], "$$.symbolList = $1.symbolList ~ $2.symbol;"));

        tag = define_non_terminal("tag", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        LITERAL = get_symbol("LITERAL", plf.next());
        add_production(new Production(tag, [IDENT],
            "if (!is_allowable_name($1.ddMatchedText)) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Illegal symbol name.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "} else {\n"
            "    $$.symbol = symbolTable.get_symbol($1.ddMatchedText, $1.ddLocation);\n"
            "    if ($$.symbol is null) {\n"
            "        $$.symbol = symbolTable.new_tag($1.ddMatchedText, $1.ddLocation);\n"
            "    } else if ($$.symbol.type == SymbolType.nonTerminal) {\n"
            "        errorCount++;\n"
            "        stderr.writefln(\"%s: %s: non terminal symbol in precedence specification.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "    }\n"
            "}\n"
            ));
        add_production(new Production(tag, [LITERAL],
            "$$.symbol = symbolTable.get_literal_token($1.ddMatchedText, $1.ddLocation);\n"
            "if ($$.symbol is null) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Unknown literal token\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "}\n"
            ));

    // Rules defining rules
        production_rules = define_non_terminal("production_rules", plf.next(true));
        auto production_group = get_symbol("production_group", plf.next(true), true);
        add_production(new Production(production_rules, [production_group], "// do nothing"));
        add_production(new Production(production_rules, [production_rules, production_group], "// do nothing"));

        production_group = define_non_terminal("production_group", plf.next(true));
        auto production_group_head = get_symbol("production_group_head", plf.next(true), true);
        auto production_tail_list = get_symbol("production_tail_list", plf.next(true), true);
        DOT = get_literal_token("\".\"", plf.next());
        add_production(new Production(production_group, [production_group_head, production_tail_list, DOT],
        "foreach (productionTail; $2.productionTailList) {\n"
        "    auto prodn = new Production($1.symbol, productionTail.rightHandSide);\n"
        "    prodn.predicate = productionTail.predicate;\n"
        "    prodn.action = productionTail.action;\n"
        "    prodn.associativity = productionTail.associatedPrecedence.associativity;\n"
        "    prodn.precedence = productionTail.associatedPrecedence.precedence;\n"
        "    grammarSpecification.add_production(prodn);\n"
        "}"
        ));

        production_group_head = define_non_terminal("production_group_head", plf.next(true));
        COLON = get_literal_token("\":\"", plf.next());
        auto left_hand_side = get_symbol("left_hand_side", plf.next(true), true);
        add_production(new Production(production_group_head, [left_hand_side, COLON], "$$.symbol = symbolTable.define_non_terminal($1.ddMatchedText, $1.ddLocation);"));

        left_hand_side = define_non_terminal("left_hand_side", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        add_production(new Production(left_hand_side, [IDENT],
            "if (!is_allowable_name($1.ddMatchedText)) {\n"
            "    errorCount++;\n"
            "    stderr.writefln(\"%s: %s: Illegal symbol name.\", $1.ddLocation.lineNumber, $1.ddMatchedText);\n"
            "}\n"
            ));

        production_tail_list = define_non_terminal("production_tail_list", plf.next(true));
        auto production_tail = get_symbol("production_tail", plf.next(true), true);
        VBAR = get_literal_token("\"|\"", plf.next());
        add_production(new Production(production_tail_list, [production_tail], "$$.productionTailList = [$1.productionTail];"));
        add_production(new Production(production_tail_list, [production_tail_list, VBAR, production_tail], "$$.productionTailList = $1.productionTailList ~ $3.productionTail;"));

        production_tail = define_non_terminal("production_tail", plf.next(true));
        auto symbol_list = get_symbol("symbol_list", plf.next(), true);
        auto tagged_precedence = get_symbol("tagged_precedence", plf.next(), true);
        auto predicate = get_symbol("predicate", plf.next(), true);
        auto action = get_symbol("action", plf.next(), true);
        add_production(new Production(production_tail, [action], "$$.productionTail = ProductionTail([], AssociatedPrecedence(), null, $1.semanticAction);"));
        add_production(new Production(production_tail, [symbol_list, predicate, tagged_precedence, action], "$$.productionTail = ProductionTail($1.symbolList, $3.associatedPrecedence, $2.predicate, $4.semanticAction);"));
        add_production(new Production(production_tail, [symbol_list, predicate, tagged_precedence], "$$.productionTail = ProductionTail($1.symbolList, $3.associatedPrecedence, $2.predicate, null);"));
        add_production(new Production(production_tail, [symbol_list, predicate, action], "$$.productionTail = ProductionTail($1.symbolList, AssociatedPrecedence(), $2.predicate, $3.semanticAction);"));
        add_production(new Production(production_tail, [symbol_list, predicate], "$$.productionTail = ProductionTail($1.symbolList, AssociatedPrecedence(), $2.predicate, null);"));
        add_production(new Production(production_tail, [symbol_list, tagged_precedence, action], "$$.productionTail = ProductionTail($1.symbolList, $2.associatedPrecedence, null, $3.semanticAction);"));
        add_production(new Production(production_tail, [symbol_list, tagged_precedence], "$$.productionTail = ProductionTail($1.symbolList, $2.associatedPrecedence);"));
        add_production(new Production(production_tail, [symbol_list, action], "$$.productionTail = ProductionTail($1.symbolList, AssociatedPrecedence(), null, $2.semanticAction);"));
        add_production(new Production(production_tail, [symbol_list], "$$.productionTail = ProductionTail($1.symbolList);"));

        action = define_non_terminal("action", plf.next(true));
        ACTION = get_symbol("ACTION", plf.next());
        add_production(new Production(action, [ACTION], "$$.semanticAction = $1.ddMatchedText[2 .. $ - 2];"));

        predicate = define_non_terminal("predicate", plf.next(true));
        PREDICATE = get_symbol("PREDICATE", plf.next());
        add_production(new Production(predicate, [PREDICATE], "$$.predicate = $1.ddMatchedText[2 .. $ - 2];"));

        tagged_precedence = define_non_terminal("tagged_precedence", plf.next(true));
        PRECEDENCE = get_literal_token("\"%prec\"", plf.next());
        IDENT = get_symbol("IDENT", plf.next(true));
        LITERAL = get_symbol("LITERAL", plf.next());
        add_production(new Production(tagged_precedence, [PRECEDENCE, IDENT],
            "auto symbol = symbolTable.get_symbol($2.ddMatchedText, $2.ddLocation, false);\n"
            "if (symbol is null) {\n"
            "    stderr.writefln(\"%s: Unknown symbol.\", $2.ddMatchedText);\n"
            "    errorCount++;\n"
            "} else if (symbol.type == SymbolType.nonTerminal) {\n"
            "    stderr.writefln(\"%s: Illegal precedence tag (must be Token or Tag).\", $2.ddMatchedText);\n"
            "    errorCount++;\n"
            "}\n"
            "$$.associatedPrecedence = AssociatedPrecedence(symbol.associativity, symbol.precedence);"
        ));
        add_production(new Production(tagged_precedence, [PRECEDENCE, LITERAL],
            "if (symbolTable.is_known_literal($2.ddMatchedText)) {\n"
            "    auto symbol = symbolTable.get_literal_token($2.ddMatchedText, $2.ddLocation);\n"
            "    $$.associatedPrecedence = AssociatedPrecedence(symbol.associativity, symbol.precedence);\n"
            "} else {\n"
            "    stderr.writefln(\"%s: Unknown literal token.\", $2.ddMatchedText);\n"
            "    errorCount++;\n"
            "}\n"
        ));

        symbol_list = define_non_terminal("symbol_list", plf.next(true));
        auto symbol = get_symbol("symbol", plf.next(true), true);
        add_production(new Production(symbol_list, [symbol], "$$.symbolList = [$1.symbol];"));
        add_production(new Production(symbol_list, [symbol_list, symbol], "$$.symbolList = $1.symbolList ~ $2.symbol;"));

        symbol = define_non_terminal("symbol", plf.next(true));
        IDENT = get_symbol("IDENT", plf.next(true));
        ERROR = get_literal_token("\"%error\"", plf.next());
        LEXERROR = get_literal_token("\"%lexerror\"", plf.next());
        LITERAL = get_symbol("LITERAL", plf.next());
        add_production(new Production(symbol, [IDENT],
            "$$.symbol = symbolTable.get_symbol($1.ddMatchedText, $1.ddLocation, true);\n"
            "if ($$.symbol is null) {\n"
            "    stderr.writefln(\"%s: Unknown symbol.\", $1.ddMatchedText);\n"
            "    errorCount++;\n"
            "}\n"
        ));
        add_production(new Production(symbol, [LITERAL],
            "if (symbolTable.is_known_literal($1.ddMatchedText)) {\n"
            "    $$.symbol = symbolTable.get_literal_token($1.ddMatchedText, $1.ddLocation);\n"
            "} else {\n"
            "    stderr.writefln(\"%s: Unknown literal token.\", $1.ddMatchedText);\n"
            "    errorCount++;\n"
            "}\n"
        ));
        add_production(new Production(symbol, [ERROR], "$$.symbol = symbolTable.get_special_symbol(SpecialSymbols.parseError);"));
        add_production(new Production(symbol, [LEXERROR], "$$.symbol = symbolTable.get_special_symbol(SpecialSymbols.lexError);"));
    }
    assert(bespokeSymbolTable.get_undefined_symbols().length == 0);
    assert(bespokeSymbolTable.get_unused_symbols().length == 0);
    if (verbose) {
        writeln("Tokens:");
        foreach (token; bespokeSymbolTable.get_tokens_ordered()) {
            writefln("\t%s %s %s", token.id, token.name, token.pattern);
        }
        writeln("Productions:");
        for (auto prid = 0; prid < bespokeGrammarSpecification.productionList.length; prid++) {
            writefln("\t%s", bespokeGrammarSpecification.productionList[prid]);
        }
    }
    bespokeGrammar = new Grammar(bespokeGrammarSpecification);
    assert(bespokeGrammar.unresolvedRRConflicts == 0);
    assert(bespokeGrammar.unresolvedSRConflicts == 0);
    if (verbose) {
        writeln(bespokeGrammar.get_parser_states_description());
    }
}

bool force;
string moduleName;

int main(string[] args)
{
    getopt(args, "f|force", &force, "module", &moduleName, "v|verbose", &verbose);
    if (args.length != 2) {
        print_usage(args[0]);
        return -1;
    }
    generate_grammar();
    auto outputFilePath = args[1];
    // Don't overwrite existing files without specific authorization
    if (!force && exists(outputFilePath)) {
        stderr.writefln("%s: already exists: use --force (or -f) to overwrite", outputFilePath);
        return 1;
    }
    auto outputFile = File(outputFilePath, "w");
    bespokeGrammar.write_parser_code(outputFile, moduleName);
    return 0;
}

void print_usage(string command)
{
    writefln("Usage: %s [--force|-f] [--verbose|-v] [--module=<module name>] <output file>", command);
}
