// bootstrap.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import ddlib.templates;

mixin DDParserSupport;

alias ushort DDSymbol;

enum DDToken : DDSymbol {
    ddEND = 1,
    ddLEXERROR = 2,
    REGEX = 4,
    LITERAL = 5,
    TOKEN = 6,
    FIELD = 7,
    LEFT = 8,
    RIGHT = 9,
    NONASSOC = 10,
    PRECEDENCE = 11,
    SKIP = 12,
    ERROR = 13,
    LEXERROR = 14,
    NEWSECTION = 15,
    COLON = 16,
    VBAR = 17,
    DOT = 18,
    IDENT = 19,
    FIELDNAME = 20,
    PREDICATE = 21,
    ACTION = 22,
    DCODE = 23,
}

string dd_literal_token_string(DDToken ddToken)
{
    with (DDToken) switch (ddToken) {
    case TOKEN: return "%token"; break;
    case FIELD: return "%field"; break;
    case LEFT: return "%left"; break;
    case RIGHT: return "%right"; break;
    case NONASSOC: return "%nonassoc"; break;
    case PRECEDENCE: return "%prec"; break;
    case SKIP: return "%skip"; break;
    case ERROR: return "%error"; break;
    case LEXERROR: return "%lexerror"; break;
    case NEWSECTION: return "%%"; break;
    case COLON: return ":"; break;
    case VBAR: return "|"; break;
    case DOT: return "."; break;
    default:
    }
    return null;
}

enum DDNonTerminal : DDSymbol {
    ddSTART = 0,
    ddERROR = 3,
    specification = 24,
    preamble = 25,
    definitions = 26,
    production_rules = 27,
    coda = 28,
    field_definitions = 29,
    token_definitions = 30,
    skip_definitions = 31,
    precedence_definitions = 32,
    field_definition = 33,
    fieldType = 34,
    fieldName = 35,
    fieldConversionFunction = 36,
    token_definition = 37,
    new_token_name = 38,
    pattern = 39,
    skip_definition = 40,
    precedence_definition = 41,
    tag_list = 42,
    tag = 43,
    production_group = 44,
    production_group_head = 45,
    production_tail_list = 46,
    production_tail = 47,
    action = 48,
    predicate = 49,
    symbol_list = 50,
    tagged_precedence = 51,
    symbol = 52,
}

static DDLexicalAnalyserSpecification ddLexicalAnalyserSpecification;
static this() {
    DDTokenSpec[] ddTokenSpecs = [
        new DDTokenSpec(DDToken.REGEX, `(\(.+\)(?=\s))`),
        new DDTokenSpec(DDToken.LITERAL, `("\S+")`),
        new DDTokenSpec(DDToken.TOKEN, `"%token"`),
        new DDTokenSpec(DDToken.FIELD, `"%field"`),
        new DDTokenSpec(DDToken.LEFT, `"%left"`),
        new DDTokenSpec(DDToken.RIGHT, `"%right"`),
        new DDTokenSpec(DDToken.NONASSOC, `"%nonassoc"`),
        new DDTokenSpec(DDToken.PRECEDENCE, `"%prec"`),
        new DDTokenSpec(DDToken.SKIP, `"%skip"`),
        new DDTokenSpec(DDToken.ERROR, `"%error"`),
        new DDTokenSpec(DDToken.LEXERROR, `"%lexerror"`),
        new DDTokenSpec(DDToken.NEWSECTION, `"%%"`),
        new DDTokenSpec(DDToken.COLON, `":"`),
        new DDTokenSpec(DDToken.VBAR, `"|"`),
        new DDTokenSpec(DDToken.DOT, `"."`),
        new DDTokenSpec(DDToken.IDENT, `([a-zA-Z]+[a-zA-Z0-9_]*)`),
        new DDTokenSpec(DDToken.FIELDNAME, `(<[a-zA-Z]+[a-zA-Z0-9_]*>)`),
        new DDTokenSpec(DDToken.PREDICATE, `(\?\((.|[\n\r])*?\?\))`),
        new DDTokenSpec(DDToken.ACTION, `(!\{(.|[\n\r])*?!\})`),
        new DDTokenSpec(DDToken.DCODE, `(%\{(.|[\n\r])*?%\})`),
    ];

    static string[] ddSkipRules = [
        `(/\*(.|[\n\r])*?\*/)`,
        `(//[^\n\r]*)`,
        `(\s+)`,
    ];

    ddLexicalAnalyserSpecification = new DDLexicalAnalyserSpecification(ddTokenSpecs, ddSkipRules);
}

alias uint DDProduction;
DDProductionData dd_get_production_data(DDProduction ddProduction)
{
    with (DDNonTerminal) switch(ddProduction) {
    case 0: return DDProductionData(ddSTART, 1);
    case 1: return DDProductionData(specification, 5);
    case 2: return DDProductionData(preamble, 0);
    case 3: return DDProductionData(preamble, 1);
    case 4: return DDProductionData(preamble, 2);
    case 5: return DDProductionData(coda, 0);
    case 6: return DDProductionData(coda, 1);
    case 7: return DDProductionData(definitions, 4);
    case 8: return DDProductionData(field_definitions, 0);
    case 9: return DDProductionData(field_definitions, 2);
    case 10: return DDProductionData(field_definition, 3);
    case 11: return DDProductionData(field_definition, 4);
    case 12: return DDProductionData(fieldType, 1);
    case 13: return DDProductionData(fieldType, 1);
    case 14: return DDProductionData(fieldName, 1);
    case 15: return DDProductionData(fieldName, 1);
    case 16: return DDProductionData(fieldConversionFunction, 1);
    case 17: return DDProductionData(fieldConversionFunction, 1);
    case 18: return DDProductionData(token_definitions, 1);
    case 19: return DDProductionData(token_definitions, 2);
    case 20: return DDProductionData(token_definition, 3);
    case 21: return DDProductionData(token_definition, 4);
    case 22: return DDProductionData(new_token_name, 1);
    case 23: return DDProductionData(new_token_name, 1);
    case 24: return DDProductionData(pattern, 1);
    case 25: return DDProductionData(pattern, 1);
    case 26: return DDProductionData(skip_definitions, 0);
    case 27: return DDProductionData(skip_definitions, 2);
    case 28: return DDProductionData(skip_definition, 2);
    case 29: return DDProductionData(precedence_definitions, 0);
    case 30: return DDProductionData(precedence_definitions, 2);
    case 31: return DDProductionData(precedence_definition, 2);
    case 32: return DDProductionData(precedence_definition, 2);
    case 33: return DDProductionData(precedence_definition, 2);
    case 34: return DDProductionData(tag_list, 1);
    case 35: return DDProductionData(tag_list, 2);
    case 36: return DDProductionData(tag, 1);
    case 37: return DDProductionData(tag, 1);
    case 38: return DDProductionData(tag, 1);
    case 39: return DDProductionData(tag, 1);
    case 40: return DDProductionData(production_rules, 1);
    case 41: return DDProductionData(production_rules, 2);
    case 42: return DDProductionData(production_group, 3);
    case 43: return DDProductionData(production_group_head, 2);
    case 44: return DDProductionData(production_group_head, 2);
    case 45: return DDProductionData(production_group_head, 2);
    case 46: return DDProductionData(production_tail_list, 1);
    case 47: return DDProductionData(production_tail_list, 3);
    case 48: return DDProductionData(production_tail, 0);
    case 49: return DDProductionData(production_tail, 1);
    case 50: return DDProductionData(production_tail, 2);
    case 51: return DDProductionData(production_tail, 1);
    case 52: return DDProductionData(production_tail, 4);
    case 53: return DDProductionData(production_tail, 3);
    case 54: return DDProductionData(production_tail, 3);
    case 55: return DDProductionData(production_tail, 2);
    case 56: return DDProductionData(production_tail, 3);
    case 57: return DDProductionData(production_tail, 2);
    case 58: return DDProductionData(production_tail, 2);
    case 59: return DDProductionData(production_tail, 1);
    case 60: return DDProductionData(action, 1);
    case 61: return DDProductionData(predicate, 1);
    case 62: return DDProductionData(tagged_precedence, 2);
    case 63: return DDProductionData(tagged_precedence, 2);
    case 64: return DDProductionData(symbol_list, 1);
    case 65: return DDProductionData(symbol_list, 2);
    case 66: return DDProductionData(symbol, 1);
    case 67: return DDProductionData(symbol, 1);
    case 68: return DDProductionData(symbol, 1);
    case 69: return DDProductionData(symbol, 1);
    default:
        throw new Exception("Malformed production data table");
    }
    assert(false);
}

struct DDAttributes {
    DDCharLocation ddLocation;
    string ddMatchedText;
    union {
        DDSyntaxErrorData ddSyntaxErrorData;
        Symbol symbol;
        SemanticAction semanticAction;
        ProductionTail productionTail;
        SymbolList symbolList;
        Predicate predicate;
        AssociativePrecedence associativePrecedence;
        ProductionTailList productionTailList;
        StringList stringList;
    }
}


void dd_set_attribute_value(ref DDAttributes attrs, DDToken ddToken, string text)
{
}

alias uint DDParserState;
DDParserState dd_get_goto_state(DDNonTerminal ddNonTerminal, DDParserState ddCurrentState)
{
    with (DDNonTerminal) switch(ddCurrentState) {
    case 0:
        switch (ddNonTerminal) {
        case specification: return 1;
        case preamble: return 2;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 0)", ddNonTerminal));
        }
        break;
    case 2:
        switch (ddNonTerminal) {
        case definitions: return 4;
        case field_definitions: return 5;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 2)", ddNonTerminal));
        }
        break;
    case 5:
        switch (ddNonTerminal) {
        case token_definitions: return 8;
        case field_definition: return 9;
        case token_definition: return 11;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 5)", ddNonTerminal));
        }
        break;
    case 7:
        switch (ddNonTerminal) {
        case production_rules: return 13;
        case production_group: return 14;
        case production_group_head: return 15;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 7)", ddNonTerminal));
        }
        break;
    case 8:
        switch (ddNonTerminal) {
        case skip_definitions: return 17;
        case token_definition: return 18;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 8)", ddNonTerminal));
        }
        break;
    case 10:
        switch (ddNonTerminal) {
        case fieldType: return 19;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 10)", ddNonTerminal));
        }
        break;
    case 12:
        switch (ddNonTerminal) {
        case new_token_name: return 21;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 12)", ddNonTerminal));
        }
        break;
    case 13:
        switch (ddNonTerminal) {
        case coda: return 24;
        case production_group: return 26;
        case production_group_head: return 15;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 13)", ddNonTerminal));
        }
        break;
    case 15:
        switch (ddNonTerminal) {
        case production_tail_list: return 27;
        case production_tail: return 28;
        case action: return 29;
        case predicate: return 30;
        case symbol_list: return 31;
        case symbol: return 34;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 15)", ddNonTerminal));
        }
        break;
    case 17:
        switch (ddNonTerminal) {
        case precedence_definitions: return 40;
        case skip_definition: return 41;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 17)", ddNonTerminal));
        }
        break;
    case 19:
        switch (ddNonTerminal) {
        case fieldName: return 43;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 19)", ddNonTerminal));
        }
        break;
    case 21:
        switch (ddNonTerminal) {
        case pattern: return 45;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 21)", ddNonTerminal));
        }
        break;
    case 22:
        switch (ddNonTerminal) {
        case new_token_name: return 48;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 22)", ddNonTerminal));
        }
        break;
    case 30:
        switch (ddNonTerminal) {
        case action: return 51;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 30)", ddNonTerminal));
        }
        break;
    case 31:
        switch (ddNonTerminal) {
        case action: return 54;
        case predicate: return 52;
        case tagged_precedence: return 53;
        case symbol: return 56;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 31)", ddNonTerminal));
        }
        break;
    case 40:
        switch (ddNonTerminal) {
        case precedence_definition: return 57;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 40)", ddNonTerminal));
        }
        break;
    case 43:
        switch (ddNonTerminal) {
        case fieldConversionFunction: return 62;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 43)", ddNonTerminal));
        }
        break;
    case 48:
        switch (ddNonTerminal) {
        case pattern: return 64;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 48)", ddNonTerminal));
        }
        break;
    case 50:
        switch (ddNonTerminal) {
        case production_tail: return 65;
        case action: return 29;
        case predicate: return 30;
        case symbol_list: return 31;
        case symbol: return 34;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 50)", ddNonTerminal));
        }
        break;
    case 52:
        switch (ddNonTerminal) {
        case action: return 67;
        case tagged_precedence: return 66;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 52)", ddNonTerminal));
        }
        break;
    case 53:
        switch (ddNonTerminal) {
        case action: return 68;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 53)", ddNonTerminal));
        }
        break;
    case 58:
        switch (ddNonTerminal) {
        case tag_list: return 71;
        case tag: return 72;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 58)", ddNonTerminal));
        }
        break;
    case 59:
        switch (ddNonTerminal) {
        case tag_list: return 75;
        case tag: return 72;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 59)", ddNonTerminal));
        }
        break;
    case 60:
        switch (ddNonTerminal) {
        case tag_list: return 76;
        case tag: return 72;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 60)", ddNonTerminal));
        }
        break;
    case 66:
        switch (ddNonTerminal) {
        case action: return 77;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 66)", ddNonTerminal));
        }
        break;
    case 71:
        switch (ddNonTerminal) {
        case tag: return 78;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 71)", ddNonTerminal));
        }
        break;
    case 75:
        switch (ddNonTerminal) {
        case tag: return 78;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 75)", ddNonTerminal));
        }
        break;
    case 76:
        switch (ddNonTerminal) {
        case tag: return 78;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 76)", ddNonTerminal));
        }
        break;
    default:
        throw new Exception(format("Malformed goto table: no entry for (%s, %s).", ddNonTerminal, ddCurrentState));
    }
    throw new Exception(format("Malformed goto table: no entry for (%s, %s).", ddNonTerminal, ddCurrentState));
}

bool dd_error_recovery_ok(DDParserState ddParserState, DDToken ddToken)
{
    with (DDToken) switch(ddParserState) {
    default:
    }
    return false;
}


import std.string;

import ddlib.lexan;
import symbols;
import grammar;

GrammarSpecification grammarSpecification;

struct ProductionTail {
    Symbol[] rightHandSide;
    AssociativePrecedence associativePrecedence;
    Predicate predicate;
    SemanticAction action;
}

// Aliases for use in field definitions
alias ProductionTail[] ProductionTailList;
alias Symbol[] SymbolList;
alias string[] StringList;

uint errorCount;
uint warningCount;

void message(T...)(const CharLocation locn, const string tag, const string format, T args)
{
    stderr.writef("%s:%s:", locn, tag);
    stderr.writefln(format, args);
    stderr.flush();
}

void warning(T...)(const CharLocation locn, const string format, T args)
{
    message(locn, "Warning", format, args);
    warningCount++;
}

void error(T...)(const CharLocation locn, const string format, T args)
{
    message(locn, "Error", format, args);
    errorCount++;
}

GrammarSpecification parse_specification_text(string text, string label="") {
    auto grammarSpecification = new GrammarSpecification();

void
dd_do_semantic_action(ref DDAttributes ddLhs, DDProduction ddProduction, DDAttributes[] ddArgs)
{
    switch(ddProduction) {
    case 2: // preamble: <empty>
        // no preamble defined so there's nothing to do
        break;
    case 3: // preamble: DCODE
        grammarSpecification.set_preamble(ddArgs[1 - 1].ddMatchedText[2 .. $ - 2]);
        break;
    case 4: // preamble: DCODE DCODE
        grammarSpecification.set_header(ddArgs[1 - 1].ddMatchedText[2 .. $ - 2]);
        grammarSpecification.set_preamble(ddArgs[2 - 1].ddMatchedText[2 .. $ - 2]);
        break;
    case 5: // coda: <empty>
        // no coda defined so there's nothing to do
        break;
    case 6: // coda: DCODE
        grammarSpecification.set_coda(ddArgs[1 - 1].ddMatchedText[2 .. $ - 2]);
        break;
    case 8: // field_definitions: <empty>
        // do nothing
        break;
    case 10: // field_definition: "%field" fieldType fieldName
        if (grammarSpecification.symbolTable.is_known_field(ddArgs[3 - 1].ddMatchedText)) {
            auto previous = grammarSpecification.symbolTable.get_field_defined_at(ddArgs[3 - 1].ddMatchedText);
            error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
        } else {
            grammarSpecification.symbolTable.new_field(ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddMatchedText, "", ddArgs[3 - 1].ddLocation);
        }
        break;
    case 11: // field_definition: "%field" fieldType fieldName fieldConversionFunction
        if (grammarSpecification.symbolTable.is_known_field(ddArgs[3 - 1].ddMatchedText)) {
            auto previous = grammarSpecification.symbolTable.get_field_defined_at(ddArgs[3 - 1].ddMatchedText);
            error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
        } else {
            grammarSpecification.symbolTable.new_field(ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation);
        }
        break;
    case 12: // fieldType: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
        warning(ddArgs[1 - 1].ddLocation, "field type name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        break;
    case 14: // fieldName: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
        warning(ddArgs[1 - 1].ddLocation, "field name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        break;
    case 16: // fieldConversionFunction: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
        warning(ddArgs[1 - 1].ddLocation, "field conversion function name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        break;
    case 20: // token_definition: "%token" new_token_name pattern
        if (grammarSpecification.symbolTable.is_known_symbol(ddArgs[2 - 1].ddMatchedText)) {
            auto previous = grammarSpecification.symbolTable.get_declaration_point(ddArgs[2 - 1].ddMatchedText);
            error(ddArgs[2 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
        } else {
            grammarSpecification.symbolTable.new_token(ddArgs[2 - 1].ddMatchedText, ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation);
        }
        break;
    case 21: // token_definition: "%token" FIELDNAME new_token_name pattern
        auto fieldName = ddArgs[2 - 1].ddMatchedText[1 .. $ - 1];
        if (grammarSpecification.symbolTable.is_known_symbol(ddArgs[3 - 1].ddMatchedText)) {
            auto previous = grammarSpecification.symbolTable.get_declaration_point(ddArgs[3 - 1].ddMatchedText);
            error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
        } else if (!grammarSpecification.symbolTable.is_known_field(fieldName)) {
            error(ddArgs[2 - 1].ddLocation, "field name \"%s\" is not known.", fieldName);
            grammarSpecification.symbolTable.new_token(ddArgs[3 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation);
        } else {
            grammarSpecification.symbolTable.new_token(ddArgs[3 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation, fieldName);
        }
        break;
    case 22: // new_token_name: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
        warning(ddArgs[1 - 1].ddLocation, "token name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        break;
    case 26: // skip_definitions: <empty>
        // do nothing
        break;
    case 28: // skip_definition: "%skip" REGEX
        grammarSpecification.symbolTable.add_skip_rule(ddArgs[2 - 1].ddMatchedText);
        break;
    case 29: // precedence_definitions: <empty>
        // do nothing
        break;
    case 31: // precedence_definition: "%left" tag_list
        grammarSpecification.symbolTable.set_precedences(Associativity.left, ddArgs[2 - 1].symbolList);
        break;
    case 32: // precedence_definition: "%right" tag_list
        grammarSpecification.symbolTable.set_precedences(Associativity.right, ddArgs[2 - 1].symbolList);
        break;
    case 33: // precedence_definition: "%nonassoc" tag_list
        grammarSpecification.symbolTable.set_precedences(Associativity.nonassoc, ddArgs[2 - 1].symbolList);
        break;
    case 34: // tag_list: tag
        if (ddArgs[1 - 1].symbol is null) {
            ddLhs.symbolList = [];
        } else {
            ddLhs.symbolList = [ddArgs[1 - 1].symbol];
        }
        break;
    case 35: // tag_list: tag_list tag
        if (ddArgs[2 - 1].symbol is null) {
            ddLhs.symbolList = ddArgs[1 - 1].symbolList;
        } else {
            ddLhs.symbolList = ddArgs[1 - 1].symbolList ~ ddArgs[2 - 1].symbol;
        }
        break;
    case 36: // tag: LITERAL
        ddLhs.symbol = grammarSpecification.symbolTable.get_literal_token(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        if (ddLhs.symbol is null) {
            error(ddArgs[1 - 1].ddLocation, "Literal \"%s\" is not known.", ddArgs[1 - 1].ddMatchedText);
        }
        break;
    case 37: // tag: IDENT ?(  grammarSpecification.symbolTable.is_known_token($1.ddMatchedText)  ?)
        ddLhs.symbol = grammarSpecification.symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        break;
    case 38: // tag: IDENT ?(  grammarSpecification.symbolTable.is_known_non_terminal($1.ddMatchedText)  ?)
        ddLhs.symbol = null;
        error(ddArgs[1 - 1].ddLocation, "Non terminal \"%s\" cannot be used as precedence tag.", ddArgs[1 - 1].ddMatchedText);
        break;
    case 39: // tag: IDENT
        ddLhs.symbol = grammarSpecification.symbolTable.new_tag(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        break;
    case 42: // production_group: production_group_head production_tail_list "."
        foreach (productionTail; ddArgs[2 - 1].productionTailList) {
            grammarSpecification.new_production(ddArgs[1 - 1].symbol, productionTail.rightHandSide, productionTail.predicate, productionTail.action, productionTail.associativePrecedence);
        }
        break;
    case 43: // production_group_head: IDENT ":" ?(  grammarSpecification.symbolTable.is_known_token($1.ddMatchedText)  ?)
        auto lineNo = grammarSpecification.symbolTable.get_declaration_point(ddArgs[1 - 1].ddMatchedText).lineNumber;
        error(ddArgs[1 - 1].ddLocation, "%s: token (defined at line %s) cannot be used as left hand side", ddArgs[1 - 1].ddMatchedText, lineNo);
        ddLhs.symbol = grammarSpecification.symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        break;
    case 44: // production_group_head: IDENT ":" ?(  grammarSpecification.symbolTable.is_known_tag($1.ddMatchedText)  ?)
        auto lineNo = grammarSpecification.symbolTable.get_declaration_point(ddArgs[1 - 1].ddMatchedText).lineNumber;
        error(ddArgs[1 - 1].ddLocation, "%s: precedence tag (defined at line %s) cannot be used as left hand side", ddArgs[1 - 1].ddMatchedText, lineNo);
        ddLhs.symbol = grammarSpecification.symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        break;
    case 45: // production_group_head: IDENT ":"
        if (!is_allowable_name(ddArgs[1 - 1].ddMatchedText)) {
            warning(ddArgs[1 - 1].ddLocation, "non terminal symbol name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        }
        ddLhs.symbol = grammarSpecification.symbolTable.define_non_terminal(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        break;
    case 46: // production_tail_list: production_tail
        ddLhs.productionTailList = [ddArgs[1 - 1].productionTail];
        break;
    case 47: // production_tail_list: production_tail_list "|" production_tail
        ddLhs.productionTailList = ddArgs[1 - 1].productionTailList ~ ddArgs[3 - 1].productionTail;
        break;
    case 48: // production_tail: <empty>
        ddLhs.productionTail = ProductionTail([], AssociativePrecedence(), null, null);
        break;
    case 49: // production_tail: action
        ddLhs.productionTail = ProductionTail([], AssociativePrecedence(), null, ddArgs[1 - 1].semanticAction);
        break;
    case 50: // production_tail: predicate action
        ddLhs.productionTail = ProductionTail([], AssociativePrecedence(), ddArgs[1 - 1].predicate, ddArgs[2 - 1].semanticAction);
        break;
    case 51: // production_tail: predicate
        ddLhs.productionTail = ProductionTail([], AssociativePrecedence(), ddArgs[1 - 1].predicate, null);
        break;
    case 52: // production_tail: symbol_list predicate tagged_precedence action
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[3 - 1].associativePrecedence, ddArgs[2 - 1].predicate, ddArgs[4 - 1].semanticAction);
        break;
    case 53: // production_tail: symbol_list predicate tagged_precedence
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[3 - 1].associativePrecedence, ddArgs[2 - 1].predicate, null);
        break;
    case 54: // production_tail: symbol_list predicate action
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociativePrecedence(), ddArgs[2 - 1].predicate, ddArgs[3 - 1].semanticAction);
        break;
    case 55: // production_tail: symbol_list predicate
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociativePrecedence(), ddArgs[2 - 1].predicate, null);
        break;
    case 56: // production_tail: symbol_list tagged_precedence action
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[2 - 1].associativePrecedence, null, ddArgs[3 - 1].semanticAction);
        break;
    case 57: // production_tail: symbol_list tagged_precedence
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[2 - 1].associativePrecedence);
        break;
    case 58: // production_tail: symbol_list action
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociativePrecedence(), null, ddArgs[2 - 1].semanticAction);
        break;
    case 59: // production_tail: symbol_list
        ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList);
        break;
    case 60: // action: ACTION
        ddLhs.semanticAction = ddArgs[1 - 1].ddMatchedText[2 .. $ - 2];
        break;
    case 61: // predicate: PREDICATE
        ddLhs.predicate = ddArgs[1 - 1].ddMatchedText[2 .. $ - 2];
        break;
    case 62: // tagged_precedence: "%prec" IDENT
        auto symbol = grammarSpecification.symbolTable.get_symbol(ddArgs[2 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation, false);
        if (symbol is null) {
            error(ddArgs[2 - 1].ddLocation, "%s: Unknown symbol.", ddArgs[2 - 1].ddMatchedText);
            ddLhs.associativePrecedence = AssociativePrecedence();
        } else if (symbol.type == SymbolType.nonTerminal) {
            error(ddArgs[2 - 1].ddLocation, "%s: Illegal precedence tag (must be Token or Tag).", ddArgs[2 - 1].ddMatchedText);
            ddLhs.associativePrecedence = AssociativePrecedence();
        } else {
            ddLhs.associativePrecedence = symbol.associativePrecedence;
        }
        break;
    case 63: // tagged_precedence: "%prec" LITERAL
        auto symbol = grammarSpecification.symbolTable.get_literal_token(ddArgs[2 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation);
        if (symbol is null) {
            ddLhs.associativePrecedence = AssociativePrecedence();
            error(ddArgs[2 - 1].ddLocation, "%s: Unknown literal token.", ddArgs[2 - 1].ddMatchedText);
        } else {
            ddLhs.associativePrecedence = symbol.associativePrecedence;
        }
        break;
    case 64: // symbol_list: symbol
        ddLhs.symbolList = [ddArgs[1 - 1].symbol];
        break;
    case 65: // symbol_list: symbol_list symbol
        ddLhs.symbolList = ddArgs[1 - 1].symbolList ~ ddArgs[2 - 1].symbol;
        break;
    case 66: // symbol: IDENT
        ddLhs.symbol = grammarSpecification.symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation, true);
        break;
    case 67: // symbol: LITERAL
        ddLhs.symbol = grammarSpecification.symbolTable.get_literal_token(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        if (ddLhs.symbol is null) {
            error(ddArgs[1 - 1].ddLocation, "%s: unknown literal token", ddArgs[1 - 1].ddMatchedText);
        }
        break;
    case 68: // symbol: "%error"
        ddLhs.symbol = grammarSpecification.symbolTable.get_special_symbol(SpecialSymbols.parseError);
        break;
    case 69: // symbol: "%lexerror"
        ddLhs.symbol = grammarSpecification.symbolTable.get_special_symbol(SpecialSymbols.lexError);;
        break;
    default:
        // Do nothing
    }
}

DDParseAction dd_get_next_action(DDParserState ddCurrentState, DDToken ddNextToken, in DDAttributes[] ddAttributeStack)
{
    with (DDToken) switch(ddCurrentState) {
    case 0:
        switch (ddNextToken) {
        case DCODE: return ddShift(3);
        case TOKEN, FIELD:
            return ddReduce(2); // preamble: <empty>
        default:
            return ddError([TOKEN, FIELD, DCODE]);
        }
        break;
    case 1:
        switch (ddNextToken) {
        case ddEND:
            return ddAccept;
        default:
            return ddError([ddEND]);
        }
        break;
    case 2:
        switch (ddNextToken) {
        case TOKEN, FIELD:
            return ddReduce(8); // field_definitions: <empty>
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 3:
        switch (ddNextToken) {
        case DCODE: return ddShift(6);
        case TOKEN, FIELD:
            return ddReduce(3); // preamble: DCODE
        default:
            return ddError([TOKEN, FIELD, DCODE]);
        }
        break;
    case 4:
        switch (ddNextToken) {
        case NEWSECTION: return ddShift(7);
        default:
            return ddError([NEWSECTION]);
        }
        break;
    case 5:
        switch (ddNextToken) {
        case TOKEN: return ddShift(12);
        case FIELD: return ddShift(10);
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 6:
        switch (ddNextToken) {
        case TOKEN, FIELD:
            return ddReduce(4); // preamble: DCODE DCODE
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 7:
        switch (ddNextToken) {
        case IDENT: return ddShift(16);
        default:
            return ddError([IDENT]);
        }
        break;
    case 8:
        switch (ddNextToken) {
        case TOKEN: return ddShift(12);
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(26); // skip_definitions: <empty>
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 9:
        switch (ddNextToken) {
        case TOKEN, FIELD:
            return ddReduce(9); // field_definitions: field_definitions field_definition
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 10:
        switch (ddNextToken) {
        case IDENT: return ddShift(20);
        default:
            return ddError([IDENT]);
        }
        break;
    case 11:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(18); // token_definitions: token_definition
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 12:
        switch (ddNextToken) {
        case IDENT: return ddShift(23);
        case FIELDNAME: return ddShift(22);
        default:
            return ddError([IDENT, FIELDNAME]);
        }
        break;
    case 13:
        switch (ddNextToken) {
        case IDENT: return ddShift(16);
        case DCODE: return ddShift(25);
        case ddEND:
            return ddReduce(5); // coda: <empty>
        default:
            return ddError([ddEND, IDENT, DCODE]);
        }
        break;
    case 14:
        switch (ddNextToken) {
        case ddEND, IDENT, DCODE:
            return ddReduce(40); // production_rules: production_group
        default:
            return ddError([ddEND, IDENT, DCODE]);
        }
        break;
    case 15:
        switch (ddNextToken) {
        case LITERAL: return ddShift(36);
        case ERROR: return ddShift(37);
        case LEXERROR: return ddShift(38);
        case IDENT: return ddShift(35);
        case PREDICATE: return ddShift(33);
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(48); // production_tail: <empty>
        default:
            return ddError([LITERAL, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 16:
        switch (ddNextToken) {
        case COLON: return ddShift(39);
        default:
            return ddError([COLON]);
        }
        break;
    case 17:
        switch (ddNextToken) {
        case SKIP: return ddShift(42);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(29); // precedence_definitions: <empty>
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 18:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(19); // token_definitions: token_definitions token_definition
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 19:
        switch (ddNextToken) {
        case IDENT: return ddShift(44);
        default:
            return ddError([IDENT]);
        }
        break;
    case 20:
        switch (ddNextToken) {
        case IDENT:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(12); // fieldType: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(13); // fieldType: IDENT
            }
        default:
            return ddError([IDENT]);
        }
        break;
    case 21:
        switch (ddNextToken) {
        case REGEX: return ddShift(46);
        case LITERAL: return ddShift(47);
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 22:
        switch (ddNextToken) {
        case IDENT: return ddShift(23);
        default:
            return ddError([IDENT]);
        }
        break;
    case 23:
        switch (ddNextToken) {
        case REGEX, LITERAL:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(22); // new_token_name: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(23); // new_token_name: IDENT
            }
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 24:
        switch (ddNextToken) {
        case ddEND:
            return ddReduce(1); // specification: preamble definitions "%%" production_rules coda
        default:
            return ddError([ddEND]);
        }
        break;
    case 25:
        switch (ddNextToken) {
        case ddEND:
            return ddReduce(6); // coda: DCODE
        default:
            return ddError([ddEND]);
        }
        break;
    case 26:
        switch (ddNextToken) {
        case ddEND, IDENT, DCODE:
            return ddReduce(41); // production_rules: production_rules production_group
        default:
            return ddError([ddEND, IDENT, DCODE]);
        }
        break;
    case 27:
        switch (ddNextToken) {
        case VBAR: return ddShift(50);
        case DOT: return ddShift(49);
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 28:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(46); // production_tail_list: production_tail
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 29:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(49); // production_tail: action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 30:
        switch (ddNextToken) {
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(51); // production_tail: predicate
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 31:
        switch (ddNextToken) {
        case LITERAL: return ddShift(36);
        case PRECEDENCE: return ddShift(55);
        case ERROR: return ddShift(37);
        case LEXERROR: return ddShift(38);
        case IDENT: return ddShift(35);
        case PREDICATE: return ddShift(33);
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(59); // production_tail: symbol_list
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 32:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(60); // action: ACTION
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 33:
        switch (ddNextToken) {
        case PRECEDENCE, VBAR, DOT, ACTION:
            return ddReduce(61); // predicate: PREDICATE
        default:
            return ddError([PRECEDENCE, VBAR, DOT, ACTION]);
        }
        break;
    case 34:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(64); // symbol_list: symbol
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 35:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(66); // symbol: IDENT
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 36:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(67); // symbol: LITERAL
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 37:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(68); // symbol: "%error"
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 38:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(69); // symbol: "%lexerror"
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 39:
        switch (ddNextToken) {
        case LITERAL, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            if ( grammarSpecification.symbolTable.is_known_token(ddAttributeStack[$ - 3 + 1].ddMatchedText) ) {
                return ddReduce(43); // production_group_head: IDENT ":" ?(  grammarSpecification.symbolTable.is_known_token($1.ddMatchedText)  ?)
            } else if ( grammarSpecification.symbolTable.is_known_tag(ddAttributeStack[$ - 3 + 1].ddMatchedText) ) {
                return ddReduce(44); // production_group_head: IDENT ":" ?(  grammarSpecification.symbolTable.is_known_tag($1.ddMatchedText)  ?)
            } else {
                return ddReduce(45); // production_group_head: IDENT ":"
            }
        default:
            return ddError([LITERAL, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 40:
        switch (ddNextToken) {
        case LEFT: return ddShift(58);
        case RIGHT: return ddShift(59);
        case NONASSOC: return ddShift(60);
        case NEWSECTION:
            return ddReduce(7); // definitions: field_definitions token_definitions skip_definitions precedence_definitions
        default:
            return ddError([LEFT, RIGHT, NONASSOC, NEWSECTION]);
        }
        break;
    case 41:
        switch (ddNextToken) {
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(27); // skip_definitions: skip_definitions skip_definition
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 42:
        switch (ddNextToken) {
        case REGEX: return ddShift(61);
        default:
            return ddError([REGEX]);
        }
        break;
    case 43:
        switch (ddNextToken) {
        case IDENT: return ddShift(63);
        case TOKEN, FIELD:
            return ddReduce(10); // field_definition: "%field" fieldType fieldName
        default:
            return ddError([TOKEN, FIELD, IDENT]);
        }
        break;
    case 44:
        switch (ddNextToken) {
        case TOKEN, FIELD, IDENT:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(14); // fieldName: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(15); // fieldName: IDENT
            }
        default:
            return ddError([TOKEN, FIELD, IDENT]);
        }
        break;
    case 45:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(20); // token_definition: "%token" new_token_name pattern
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 46:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(24); // pattern: REGEX
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 47:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(25); // pattern: LITERAL
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 48:
        switch (ddNextToken) {
        case REGEX: return ddShift(46);
        case LITERAL: return ddShift(47);
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 49:
        switch (ddNextToken) {
        case ddEND, IDENT, DCODE:
            return ddReduce(42); // production_group: production_group_head production_tail_list "."
        default:
            return ddError([ddEND, IDENT, DCODE]);
        }
        break;
    case 50:
        switch (ddNextToken) {
        case LITERAL: return ddShift(36);
        case ERROR: return ddShift(37);
        case LEXERROR: return ddShift(38);
        case IDENT: return ddShift(35);
        case PREDICATE: return ddShift(33);
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(48); // production_tail: <empty>
        default:
            return ddError([LITERAL, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 51:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(50); // production_tail: predicate action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 52:
        switch (ddNextToken) {
        case PRECEDENCE: return ddShift(55);
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(55); // production_tail: symbol_list predicate
        default:
            return ddError([PRECEDENCE, VBAR, DOT, ACTION]);
        }
        break;
    case 53:
        switch (ddNextToken) {
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(57); // production_tail: symbol_list tagged_precedence
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 54:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(58); // production_tail: symbol_list action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 55:
        switch (ddNextToken) {
        case LITERAL: return ddShift(70);
        case IDENT: return ddShift(69);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 56:
        switch (ddNextToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(65); // symbol_list: symbol_list symbol
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 57:
        switch (ddNextToken) {
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(30); // precedence_definitions: precedence_definitions precedence_definition
        default:
            return ddError([LEFT, RIGHT, NONASSOC, NEWSECTION]);
        }
        break;
    case 58:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 59:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 60:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 61:
        switch (ddNextToken) {
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(28); // skip_definition: "%skip" REGEX
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 62:
        switch (ddNextToken) {
        case TOKEN, FIELD:
            return ddReduce(11); // field_definition: "%field" fieldType fieldName fieldConversionFunction
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 63:
        switch (ddNextToken) {
        case TOKEN, FIELD:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(16); // fieldConversionFunction: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(17); // fieldConversionFunction: IDENT
            }
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 64:
        switch (ddNextToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(21); // token_definition: "%token" FIELDNAME new_token_name pattern
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 65:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(47); // production_tail_list: production_tail_list "|" production_tail
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 66:
        switch (ddNextToken) {
        case ACTION: return ddShift(32);
        case VBAR, DOT:
            return ddReduce(53); // production_tail: symbol_list predicate tagged_precedence
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 67:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(54); // production_tail: symbol_list predicate action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 68:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(56); // production_tail: symbol_list tagged_precedence action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 69:
        switch (ddNextToken) {
        case VBAR, DOT, ACTION:
            return ddReduce(62); // tagged_precedence: "%prec" IDENT
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 70:
        switch (ddNextToken) {
        case VBAR, DOT, ACTION:
            return ddReduce(63); // tagged_precedence: "%prec" LITERAL
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 71:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(31); // precedence_definition: "%left" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 72:
        switch (ddNextToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(34); // tag_list: tag
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 73:
        switch (ddNextToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(36); // tag: LITERAL
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 74:
        switch (ddNextToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            if ( grammarSpecification.symbolTable.is_known_token(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(37); // tag: IDENT ?(  grammarSpecification.symbolTable.is_known_token($1.ddMatchedText)  ?)
            } else if ( grammarSpecification.symbolTable.is_known_non_terminal(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(38); // tag: IDENT ?(  grammarSpecification.symbolTable.is_known_non_terminal($1.ddMatchedText)  ?)
            } else {
                return ddReduce(39); // tag: IDENT
            }
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 75:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(32); // precedence_definition: "%right" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 76:
        switch (ddNextToken) {
        case LITERAL: return ddShift(73);
        case IDENT: return ddShift(74);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(33); // precedence_definition: "%nonassoc" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 77:
        switch (ddNextToken) {
        case VBAR, DOT:
            return ddReduce(52); // production_tail: symbol_list predicate tagged_precedence action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 78:
        switch (ddNextToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(35); // tag_list: tag_list tag
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    default:
        throw new Exception(format("Invalid parser state: %s", ddCurrentState));
    }
    assert(false);
}


mixin DDImplementParser;

    if (!dd_parse_text(text, label)) return null;
    return grammarSpecification;
}
