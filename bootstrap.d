
// dunnart.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)
module dunnart;

import std.string;

import ddlib.lexan;
import symbols;
import grammar;

SymbolTable symbolTable;
GrammarSpecification grammarSpecification;

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

static this() {
    symbolTable = new SymbolTable;
    grammarSpecification = new GrammarSpecification(symbolTable);
}

uint errorCount;
uint warningCount;

void
message(T...)(const CharLocation locn, const string tag, const string format, T args)
{
    stderr.writef("%s:%s:", locn, tag);
    stderr.writefln(format, args);
    stderr.flush();
}

void
warning(T...)(const CharLocation locn, const string format, T args)
{
    message(locn, "Warning", format, args);
    warningCount++;
}

void
error(T...)(const CharLocation locn, const string format, T args)
{
    message(locn, "Error", format, args);
    errorCount++;
}

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
    field_definitions = 28,
    token_definitions = 29,
    skip_definitions = 30,
    precedence_definitions = 31,
    field_definition = 32,
    fieldType = 33,
    fieldName = 34,
    fieldConversionFunction = 35,
    token_definition = 36,
    new_token_name = 37,
    pattern = 38,
    skip_definition = 39,
    precedence_definition = 40,
    tag_list = 41,
    tag = 42,
    production_group = 43,
    production_group_head = 44,
    production_tail_list = 45,
    production_tail = 46,
    action = 47,
    symbol_list = 48,
    predicate = 49,
    tagged_precedence = 50,
    symbol = 51,
}

alias uint DDProduction;
DDProductionData dd_get_production_data(DDProduction ddProduction)
{
    with (DDNonTerminal) switch(ddProduction) {
    case 0: return DDProductionData(ddSTART, 1);
    case 1: return DDProductionData(specification, 4);
    case 2: return DDProductionData(preamble, 0);
    case 3: return DDProductionData(preamble, 1);
    case 4: return DDProductionData(definitions, 4);
    case 5: return DDProductionData(field_definitions, 0);
    case 6: return DDProductionData(field_definitions, 2);
    case 7: return DDProductionData(field_definition, 3);
    case 8: return DDProductionData(field_definition, 4);
    case 9: return DDProductionData(fieldType, 1);
    case 10: return DDProductionData(fieldType, 1);
    case 11: return DDProductionData(fieldName, 1);
    case 12: return DDProductionData(fieldName, 1);
    case 13: return DDProductionData(fieldConversionFunction, 1);
    case 14: return DDProductionData(fieldConversionFunction, 1);
    case 15: return DDProductionData(token_definitions, 1);
    case 16: return DDProductionData(token_definitions, 2);
    case 17: return DDProductionData(token_definition, 3);
    case 18: return DDProductionData(token_definition, 4);
    case 19: return DDProductionData(new_token_name, 1);
    case 20: return DDProductionData(new_token_name, 1);
    case 21: return DDProductionData(pattern, 1);
    case 22: return DDProductionData(pattern, 1);
    case 23: return DDProductionData(skip_definitions, 0);
    case 24: return DDProductionData(skip_definitions, 2);
    case 25: return DDProductionData(skip_definition, 2);
    case 26: return DDProductionData(precedence_definitions, 0);
    case 27: return DDProductionData(precedence_definitions, 2);
    case 28: return DDProductionData(precedence_definition, 2);
    case 29: return DDProductionData(precedence_definition, 2);
    case 30: return DDProductionData(precedence_definition, 2);
    case 31: return DDProductionData(tag_list, 1);
    case 32: return DDProductionData(tag_list, 2);
    case 33: return DDProductionData(tag, 1);
    case 34: return DDProductionData(tag, 1);
    case 35: return DDProductionData(tag, 1);
    case 36: return DDProductionData(tag, 1);
    case 37: return DDProductionData(production_rules, 1);
    case 38: return DDProductionData(production_rules, 2);
    case 39: return DDProductionData(production_group, 3);
    case 40: return DDProductionData(production_group_head, 2);
    case 41: return DDProductionData(production_group_head, 2);
    case 42: return DDProductionData(production_group_head, 2);
    case 43: return DDProductionData(production_tail_list, 1);
    case 44: return DDProductionData(production_tail_list, 3);
    case 45: return DDProductionData(production_tail, 1);
    case 46: return DDProductionData(production_tail, 4);
    case 47: return DDProductionData(production_tail, 3);
    case 48: return DDProductionData(production_tail, 3);
    case 49: return DDProductionData(production_tail, 2);
    case 50: return DDProductionData(production_tail, 3);
    case 51: return DDProductionData(production_tail, 2);
    case 52: return DDProductionData(production_tail, 2);
    case 53: return DDProductionData(production_tail, 1);
    case 54: return DDProductionData(action, 1);
    case 55: return DDProductionData(predicate, 1);
    case 56: return DDProductionData(tagged_precedence, 2);
    case 57: return DDProductionData(tagged_precedence, 2);
    case 58: return DDProductionData(symbol_list, 1);
    case 59: return DDProductionData(symbol_list, 2);
    case 60: return DDProductionData(symbol, 1);
    case 61: return DDProductionData(symbol, 1);
    case 62: return DDProductionData(symbol, 1);
    case 63: return DDProductionData(symbol, 1);
    default:
        throw new Exception("Malformed production data table");
    }
    assert(false);
}

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
    case 5: // field_definitions: <empty>

            // do nothing
        
        break;
    case 7: // field_definition: "%field" fieldType fieldName

            if (symbolTable.is_known_field(ddArgs[3 - 1].ddMatchedText)) {
                auto previous = symbolTable.get_field_defined_at(ddArgs[3 - 1].ddMatchedText);
                error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
            } else {
                symbolTable.new_field(ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddMatchedText, "", ddArgs[3 - 1].ddLocation);
            }
        
        break;
    case 8: // field_definition: "%field" fieldType fieldName fieldConversionFunction

            if (symbolTable.is_known_field(ddArgs[3 - 1].ddMatchedText)) {
                auto previous = symbolTable.get_field_defined_at(ddArgs[3 - 1].ddMatchedText);
                error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
            } else {
                symbolTable.new_field(ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation);
            }
        
        break;
    case 9: // fieldType: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)

            warning(ddArgs[1 - 1].ddLocation, "field type name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        
        break;
    case 11: // fieldName: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)

            warning(ddArgs[1 - 1].ddLocation, "field name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        
        break;
    case 13: // fieldConversionFunction: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)

            warning(ddArgs[1 - 1].ddLocation, "field conversion function name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        
        break;
    case 17: // token_definition: "%token" new_token_name pattern

            if (symbolTable.is_known_symbol(ddArgs[2 - 1].ddMatchedText)) {
                auto previous = symbolTable.get_declaration_point(ddArgs[2 - 1].ddMatchedText);
                error(ddArgs[2 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
            } else {
                symbolTable.new_token(ddArgs[2 - 1].ddMatchedText, ddArgs[3 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation);
            }
        
        break;
    case 18: // token_definition: "%token" FIELDNAME new_token_name pattern

            auto fieldName = ddArgs[2 - 1].ddMatchedText[1 .. $ - 1];
            if (symbolTable.is_known_symbol(ddArgs[3 - 1].ddMatchedText)) {
                auto previous = symbolTable.get_declaration_point(ddArgs[3 - 1].ddMatchedText);
                error(ddArgs[3 - 1].ddLocation, "\"%s\" already declared at line %s.", previous.lineNumber);
            } else if (!symbolTable.is_known_field(fieldName)) {
                error(ddArgs[2 - 1].ddLocation, "field name \"%s\" is not known.", fieldName);
                symbolTable.new_token(ddArgs[3 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation);
            } else {
                symbolTable.new_token(ddArgs[3 - 1].ddMatchedText, ddArgs[4 - 1].ddMatchedText, ddArgs[3 - 1].ddLocation, fieldName);
            }
        
        break;
    case 19: // new_token_name: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)

            warning(ddArgs[1 - 1].ddLocation, "token name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
        
        break;
    case 23: // skip_definitions: <empty>

            // do nothing
        
        break;
    case 25: // skip_definition: "%skip" REGEX

            symbolTable.add_skip_rule(ddArgs[2 - 1].ddMatchedText);
        
        break;
    case 26: // precedence_definitions: <empty>

            // do nothing
        
        break;
    case 28: // precedence_definition: "%left" tag_list

            symbolTable.set_precedences(Associativity.left, ddArgs[2 - 1].symbolList);
        
        break;
    case 29: // precedence_definition: "%right" tag_list

            symbolTable.set_precedences(Associativity.right, ddArgs[2 - 1].symbolList);
        
        break;
    case 30: // precedence_definition: "%nonassoc" tag_list

            symbolTable.set_precedences(Associativity.nonassoc, ddArgs[2 - 1].symbolList);
        
        break;
    case 31: // tag_list: tag

            if (ddArgs[1 - 1].symbol is null) {
                ddLhs.symbolList = [];
            } else {
                ddLhs.symbolList = [ddArgs[1 - 1].symbol];
            }
        
        break;
    case 32: // tag_list: tag_list tag

            if (ddArgs[2 - 1].symbol is null) {
                ddLhs.symbolList = ddArgs[1 - 1].symbolList;
            } else {
                ddLhs.symbolList = ddArgs[1 - 1].symbolList ~ ddArgs[2 - 1].symbol;
            }
        
        break;
    case 33: // tag: LITERAL

            ddLhs.symbol = symbolTable.get_literal_token(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
            if (ddLhs.symbol is null) {
                error(ddArgs[1 - 1].ddLocation, "Literal \"%s\" is not known.", ddArgs[1 - 1].ddMatchedText);
            }
        
        break;
    case 34: // tag: IDENT ?(  symbolTable.is_known_token($1.ddMatchedText)  ?)

            ddLhs.symbol = symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        
        break;
    case 35: // tag: IDENT ?(  symbolTable.is_known_non_terminal($1.ddMatchedText)  ?)

            ddLhs.symbol = null;
            error(ddArgs[1 - 1].ddLocation, "Non terminal \"%s\" cannot be used as precedence tag.", ddArgs[1 - 1].ddMatchedText);
        
        break;
    case 36: // tag: IDENT

            ddLhs.symbol = symbolTable.new_tag(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        
        break;
    case 39: // production_group: production_group_head production_tail_list "."

            foreach (productionTail; ddArgs[2 - 1].productionTailList) {
                auto prodn = new Production(ddArgs[1 - 1].symbol, productionTail.rightHandSide);
                prodn.predicate = productionTail.predicate;
                prodn.action = productionTail.action;
                prodn.associativity = productionTail.associatedPrecedence.associativity;
                prodn.precedence = productionTail.associatedPrecedence.precedence;
                grammarSpecification.add_production(prodn);
            }
        
        break;
    case 40: // production_group_head: IDENT ":" ?(  symbolTable.is_known_token($1.ddMatchedText)  ?)

            auto lineNo = symbolTable.get_declaration_point(ddArgs[1 - 1].ddMatchedText).lineNumber;
            error(ddArgs[1 - 1].ddLocation, "%s: token (defined at line %s) cannot be used as left hand side", ddArgs[1 - 1].ddMatchedText, lineNo);
            ddLhs.symbol = symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        
        break;
    case 41: // production_group_head: IDENT ":" ?(  symbolTable.is_known_tag($1.ddMatchedText)  ?)

            auto lineNo = symbolTable.get_declaration_point(ddArgs[1 - 1].ddMatchedText).lineNumber;
            error(ddArgs[1 - 1].ddLocation, "%s: precedence tag (defined at line %s) cannot be used as left hand side", ddArgs[1 - 1].ddMatchedText, lineNo);
            ddLhs.symbol = symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        
        break;
    case 42: // production_group_head: IDENT ":"

            if (!is_allowable_name(ddArgs[1 - 1].ddMatchedText)) {
                warning(ddArgs[1 - 1].ddLocation, "non terminal symbol name \"%s\" may clash with generated code", ddArgs[1 - 1].ddMatchedText);
            }
            ddLhs.symbol = symbolTable.define_non_terminal(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
        
        break;
    case 43: // production_tail_list: production_tail

            ddLhs.productionTailList = [ddArgs[1 - 1].productionTail];
        
        break;
    case 44: // production_tail_list: production_tail_list "|" production_tail

            ddLhs.productionTailList = ddArgs[1 - 1].productionTailList ~ ddArgs[3 - 1].productionTail;
        
        break;
    case 45: // production_tail: action

            ddLhs.productionTail = ProductionTail([], AssociatedPrecedence(), null, ddArgs[1 - 1].semanticAction);
        
        break;
    case 46: // production_tail: symbol_list predicate tagged_precedence action

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[3 - 1].associatedPrecedence, ddArgs[2 - 1].predicate, ddArgs[4 - 1].semanticAction);
        
        break;
    case 47: // production_tail: symbol_list predicate tagged_precedence

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[3 - 1].associatedPrecedence, ddArgs[2 - 1].predicate, null);
        
        break;
    case 48: // production_tail: symbol_list predicate action

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociatedPrecedence(), ddArgs[2 - 1].predicate, ddArgs[3 - 1].semanticAction);
        
        break;
    case 49: // production_tail: symbol_list predicate

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociatedPrecedence(), ddArgs[2 - 1].predicate, null);
        
        break;
    case 50: // production_tail: symbol_list tagged_precedence action

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[2 - 1].associatedPrecedence, null, ddArgs[3 - 1].semanticAction);
        
        break;
    case 51: // production_tail: symbol_list tagged_precedence

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, ddArgs[2 - 1].associatedPrecedence);
        
        break;
    case 52: // production_tail: symbol_list action

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList, AssociatedPrecedence(), null, ddArgs[2 - 1].semanticAction);
        
        break;
    case 53: // production_tail: symbol_list

            ddLhs.productionTail = ProductionTail(ddArgs[1 - 1].symbolList);
        
        break;
    case 54: // action: ACTION

            ddLhs.semanticAction = ddArgs[1 - 1].ddMatchedText[2 .. $ - 2];
        
        break;
    case 55: // predicate: PREDICATE

            ddLhs.predicate = ddArgs[1 - 1].ddMatchedText[2 .. $ - 2];
        
        break;
    case 56: // tagged_precedence: "%prec" IDENT

            auto symbol = symbolTable.get_symbol(ddArgs[2 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation, false);
            if (symbol is null) {
                error(ddArgs[2 - 1].ddLocation, "%s: Unknown symbol.", ddArgs[2 - 1].ddMatchedText);
                ddLhs.associatedPrecedence = AssociatedPrecedence();
            } else if (symbol.type == SymbolType.nonTerminal) {
                error(ddArgs[2 - 1].ddLocation, "%s: Illegal precedence tag (must be Token or Tag).", ddArgs[2 - 1].ddMatchedText);
                ddLhs.associatedPrecedence = AssociatedPrecedence();
            } else {
                ddLhs.associatedPrecedence = AssociatedPrecedence(symbol.associativity, symbol.precedence);
            }
        
        break;
    case 57: // tagged_precedence: "%prec" LITERAL

            auto symbol = symbolTable.get_literal_token(ddArgs[2 - 1].ddMatchedText, ddArgs[2 - 1].ddLocation);
            if (symbol is null) {
                ddLhs.associatedPrecedence = AssociatedPrecedence();
                error(ddArgs[2 - 1].ddLocation, "%s: Unknown literal token.", ddArgs[2 - 1].ddMatchedText);
            } else {
                ddLhs.associatedPrecedence = AssociatedPrecedence(symbol.associativity, symbol.precedence);
            }
        
        break;
    case 58: // symbol_list: symbol

            ddLhs.symbolList = [ddArgs[1 - 1].symbol];
        
        break;
    case 59: // symbol_list: symbol_list symbol

            ddLhs.symbolList = ddArgs[1 - 1].symbolList ~ ddArgs[2 - 1].symbol;
        
        break;
    case 60: // symbol: IDENT

            ddLhs.symbol = symbolTable.get_symbol(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation, true);
        
        break;
    case 61: // symbol: LITERAL

            ddLhs.symbol = symbolTable.get_literal_token(ddArgs[1 - 1].ddMatchedText, ddArgs[1 - 1].ddLocation);
            if (ddLhs.symbol is null) {
                error(ddArgs[1 - 1].ddLocation, "%s: unknown literal token", ddArgs[1 - 1].ddMatchedText);
            }
        
        break;
    case 62: // symbol: "%error"

            ddLhs.symbol = symbolTable.get_special_symbol(SpecialSymbols.parseError);
        
        break;
    case 63: // symbol: "%lexerror"

            ddLhs.symbol = symbolTable.get_special_symbol(SpecialSymbols.lexError);;
        
        break;
    default:
        // Do nothing
    }
}

struct DDAttributes {
    DDCharLocation ddLocation;
    string ddMatchedText;
    union {
        DDSyntaxErrorData ddSyntaxErrorData;
        Symbol symbol;
        SemanticAction semanticAction;
        AssociatedPrecedence associatedPrecedence;
        ProductionTail productionTail;
        SymbolList symbolList;
        Predicate predicate;
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
        case token_definitions: return 7;
        case field_definition: return 8;
        case token_definition: return 10;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 5)", ddNonTerminal));
        }
        break;
    case 6:
        switch (ddNonTerminal) {
        case production_rules: return 12;
        case production_group: return 13;
        case production_group_head: return 14;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 6)", ddNonTerminal));
        }
        break;
    case 7:
        switch (ddNonTerminal) {
        case skip_definitions: return 16;
        case token_definition: return 17;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 7)", ddNonTerminal));
        }
        break;
    case 9:
        switch (ddNonTerminal) {
        case fieldType: return 18;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 9)", ddNonTerminal));
        }
        break;
    case 11:
        switch (ddNonTerminal) {
        case new_token_name: return 20;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 11)", ddNonTerminal));
        }
        break;
    case 12:
        switch (ddNonTerminal) {
        case production_group: return 23;
        case production_group_head: return 14;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 12)", ddNonTerminal));
        }
        break;
    case 14:
        switch (ddNonTerminal) {
        case production_tail_list: return 24;
        case production_tail: return 25;
        case action: return 26;
        case symbol_list: return 27;
        case symbol: return 29;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 14)", ddNonTerminal));
        }
        break;
    case 16:
        switch (ddNonTerminal) {
        case precedence_definitions: return 35;
        case skip_definition: return 36;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 16)", ddNonTerminal));
        }
        break;
    case 18:
        switch (ddNonTerminal) {
        case fieldName: return 38;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 18)", ddNonTerminal));
        }
        break;
    case 20:
        switch (ddNonTerminal) {
        case pattern: return 40;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 20)", ddNonTerminal));
        }
        break;
    case 21:
        switch (ddNonTerminal) {
        case new_token_name: return 43;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 21)", ddNonTerminal));
        }
        break;
    case 27:
        switch (ddNonTerminal) {
        case action: return 48;
        case predicate: return 46;
        case tagged_precedence: return 47;
        case symbol: return 51;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 27)", ddNonTerminal));
        }
        break;
    case 35:
        switch (ddNonTerminal) {
        case precedence_definition: return 52;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 35)", ddNonTerminal));
        }
        break;
    case 38:
        switch (ddNonTerminal) {
        case fieldConversionFunction: return 57;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 38)", ddNonTerminal));
        }
        break;
    case 43:
        switch (ddNonTerminal) {
        case pattern: return 59;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 43)", ddNonTerminal));
        }
        break;
    case 45:
        switch (ddNonTerminal) {
        case production_tail: return 60;
        case action: return 26;
        case symbol_list: return 27;
        case symbol: return 29;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 45)", ddNonTerminal));
        }
        break;
    case 46:
        switch (ddNonTerminal) {
        case action: return 62;
        case tagged_precedence: return 61;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 46)", ddNonTerminal));
        }
        break;
    case 47:
        switch (ddNonTerminal) {
        case action: return 63;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 47)", ddNonTerminal));
        }
        break;
    case 53:
        switch (ddNonTerminal) {
        case tag_list: return 66;
        case tag: return 67;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 53)", ddNonTerminal));
        }
        break;
    case 54:
        switch (ddNonTerminal) {
        case tag_list: return 70;
        case tag: return 67;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 54)", ddNonTerminal));
        }
        break;
    case 55:
        switch (ddNonTerminal) {
        case tag_list: return 71;
        case tag: return 67;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 55)", ddNonTerminal));
        }
        break;
    case 61:
        switch (ddNonTerminal) {
        case action: return 72;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 61)", ddNonTerminal));
        }
        break;
    case 66:
        switch (ddNonTerminal) {
        case tag: return 73;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 66)", ddNonTerminal));
        }
        break;
    case 70:
        switch (ddNonTerminal) {
        case tag: return 73;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 70)", ddNonTerminal));
        }
        break;
    case 71:
        switch (ddNonTerminal) {
        case tag: return 73;
        default:
            throw new Exception(format("Malformed goto table: no entry for (%s , 71)", ddNonTerminal));
        }
        break;
    default:
        throw new Exception(format("Malformed goto table: no entry for (%s, %s).", ddNonTerminal, ddCurrentState));
    }
    throw new Exception(format("Malformed goto table: no entry for (%s, %s).", ddNonTerminal, ddCurrentState));
}

DDParseAction dd_get_next_action(DDParserState ddCurrentState, DDToken ddToken, in DDAttributes[] ddAttributeStack)
{
    with (DDToken) switch(ddCurrentState) {
    case 0:
        switch (ddToken) {
        case DCODE: return ddShift(3);
        case TOKEN, FIELD:
            return ddReduce(2); // preamble: <empty>
        default:
            return ddError([TOKEN, FIELD, DCODE]);
        }
        break;
    case 1:
        switch (ddToken) {
        case ddEND:
            return ddAccept;
        default:
            return ddError([ddEND]);
        }
        break;
    case 2:
        switch (ddToken) {
        case TOKEN, FIELD:
            return ddReduce(5); // field_definitions: <empty>
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 3:
        switch (ddToken) {
        case TOKEN, FIELD:
            return ddReduce(3); // preamble: DCODE
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 4:
        switch (ddToken) {
        case NEWSECTION: return ddShift(6);
        default:
            return ddError([NEWSECTION]);
        }
        break;
    case 5:
        switch (ddToken) {
        case TOKEN: return ddShift(11);
        case FIELD: return ddShift(9);
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 6:
        switch (ddToken) {
        case IDENT: return ddShift(15);
        default:
            return ddError([IDENT]);
        }
        break;
    case 7:
        switch (ddToken) {
        case TOKEN: return ddShift(11);
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(23); // skip_definitions: <empty>
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 8:
        switch (ddToken) {
        case TOKEN, FIELD:
            return ddReduce(6); // field_definitions: field_definitions field_definition
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 9:
        switch (ddToken) {
        case IDENT: return ddShift(19);
        default:
            return ddError([IDENT]);
        }
        break;
    case 10:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(15); // token_definitions: token_definition
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 11:
        switch (ddToken) {
        case IDENT: return ddShift(22);
        case FIELDNAME: return ddShift(21);
        default:
            return ddError([IDENT, FIELDNAME]);
        }
        break;
    case 12:
        switch (ddToken) {
        case IDENT: return ddShift(15);
        case ddEND:
            return ddReduce(1); // specification: preamble definitions "%%" production_rules
        default:
            return ddError([ddEND, IDENT]);
        }
        break;
    case 13:
        switch (ddToken) {
        case ddEND, IDENT:
            return ddReduce(37); // production_rules: production_group
        default:
            return ddError([ddEND, IDENT]);
        }
        break;
    case 14:
        switch (ddToken) {
        case LITERAL: return ddShift(31);
        case ERROR: return ddShift(32);
        case LEXERROR: return ddShift(33);
        case IDENT: return ddShift(30);
        case ACTION: return ddShift(28);
        default:
            return ddError([LITERAL, ERROR, LEXERROR, IDENT, ACTION]);
        }
        break;
    case 15:
        switch (ddToken) {
        case COLON: return ddShift(34);
        default:
            return ddError([COLON]);
        }
        break;
    case 16:
        switch (ddToken) {
        case SKIP: return ddShift(37);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(26); // precedence_definitions: <empty>
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 17:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(16); // token_definitions: token_definitions token_definition
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 18:
        switch (ddToken) {
        case IDENT: return ddShift(39);
        default:
            return ddError([IDENT]);
        }
        break;
    case 19:
        switch (ddToken) {
        case IDENT:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(9); // fieldType: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(10); // fieldType: IDENT
            }
        default:
            return ddError([IDENT]);
        }
        break;
    case 20:
        switch (ddToken) {
        case REGEX: return ddShift(41);
        case LITERAL: return ddShift(42);
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 21:
        switch (ddToken) {
        case IDENT: return ddShift(22);
        default:
            return ddError([IDENT]);
        }
        break;
    case 22:
        switch (ddToken) {
        case REGEX, LITERAL:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(19); // new_token_name: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(20); // new_token_name: IDENT
            }
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 23:
        switch (ddToken) {
        case ddEND, IDENT:
            return ddReduce(38); // production_rules: production_rules production_group
        default:
            return ddError([ddEND, IDENT]);
        }
        break;
    case 24:
        switch (ddToken) {
        case VBAR: return ddShift(45);
        case DOT: return ddShift(44);
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 25:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(43); // production_tail_list: production_tail
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 26:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(45); // production_tail: action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 27:
        switch (ddToken) {
        case LITERAL: return ddShift(31);
        case PRECEDENCE: return ddShift(50);
        case ERROR: return ddShift(32);
        case LEXERROR: return ddShift(33);
        case IDENT: return ddShift(30);
        case PREDICATE: return ddShift(49);
        case ACTION: return ddShift(28);
        case VBAR, DOT:
            return ddReduce(53); // production_tail: symbol_list
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 28:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(54); // action: ACTION
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 29:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(58); // symbol_list: symbol
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 30:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(60); // symbol: IDENT
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 31:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(61); // symbol: LITERAL
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 32:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(62); // symbol: "%error"
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 33:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(63); // symbol: "%lexerror"
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 34:
        switch (ddToken) {
        case LITERAL, ERROR, LEXERROR, IDENT, ACTION:
            if ( symbolTable.is_known_token(ddAttributeStack[$ - 3 + 1].ddMatchedText) ) {
                return ddReduce(40); // production_group_head: IDENT ":" ?(  symbolTable.is_known_token($1.ddMatchedText)  ?)
            } else if ( symbolTable.is_known_tag(ddAttributeStack[$ - 3 + 1].ddMatchedText) ) {
                return ddReduce(41); // production_group_head: IDENT ":" ?(  symbolTable.is_known_tag($1.ddMatchedText)  ?)
            } else {
                return ddReduce(42); // production_group_head: IDENT ":"
            }
        default:
            return ddError([LITERAL, ERROR, LEXERROR, IDENT, ACTION]);
        }
        break;
    case 35:
        switch (ddToken) {
        case LEFT: return ddShift(53);
        case RIGHT: return ddShift(54);
        case NONASSOC: return ddShift(55);
        case NEWSECTION:
            return ddReduce(4); // definitions: field_definitions token_definitions skip_definitions precedence_definitions
        default:
            return ddError([LEFT, RIGHT, NONASSOC, NEWSECTION]);
        }
        break;
    case 36:
        switch (ddToken) {
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(24); // skip_definitions: skip_definitions skip_definition
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 37:
        switch (ddToken) {
        case REGEX: return ddShift(56);
        default:
            return ddError([REGEX]);
        }
        break;
    case 38:
        switch (ddToken) {
        case IDENT: return ddShift(58);
        case TOKEN, FIELD:
            return ddReduce(7); // field_definition: "%field" fieldType fieldName
        default:
            return ddError([TOKEN, FIELD, IDENT]);
        }
        break;
    case 39:
        switch (ddToken) {
        case TOKEN, FIELD, IDENT:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(11); // fieldName: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(12); // fieldName: IDENT
            }
        default:
            return ddError([TOKEN, FIELD, IDENT]);
        }
        break;
    case 40:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(17); // token_definition: "%token" new_token_name pattern
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 41:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(21); // pattern: REGEX
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 42:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(22); // pattern: LITERAL
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 43:
        switch (ddToken) {
        case REGEX: return ddShift(41);
        case LITERAL: return ddShift(42);
        default:
            return ddError([REGEX, LITERAL]);
        }
        break;
    case 44:
        switch (ddToken) {
        case ddEND, IDENT:
            return ddReduce(39); // production_group: production_group_head production_tail_list "."
        default:
            return ddError([ddEND, IDENT]);
        }
        break;
    case 45:
        switch (ddToken) {
        case LITERAL: return ddShift(31);
        case ERROR: return ddShift(32);
        case LEXERROR: return ddShift(33);
        case IDENT: return ddShift(30);
        case ACTION: return ddShift(28);
        default:
            return ddError([LITERAL, ERROR, LEXERROR, IDENT, ACTION]);
        }
        break;
    case 46:
        switch (ddToken) {
        case PRECEDENCE: return ddShift(50);
        case ACTION: return ddShift(28);
        case VBAR, DOT:
            return ddReduce(49); // production_tail: symbol_list predicate
        default:
            return ddError([PRECEDENCE, VBAR, DOT, ACTION]);
        }
        break;
    case 47:
        switch (ddToken) {
        case ACTION: return ddShift(28);
        case VBAR, DOT:
            return ddReduce(51); // production_tail: symbol_list tagged_precedence
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 48:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(52); // production_tail: symbol_list action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 49:
        switch (ddToken) {
        case PRECEDENCE, VBAR, DOT, ACTION:
            return ddReduce(55); // predicate: PREDICATE
        default:
            return ddError([PRECEDENCE, VBAR, DOT, ACTION]);
        }
        break;
    case 50:
        switch (ddToken) {
        case LITERAL: return ddShift(65);
        case IDENT: return ddShift(64);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 51:
        switch (ddToken) {
        case LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION:
            return ddReduce(59); // symbol_list: symbol_list symbol
        default:
            return ddError([LITERAL, PRECEDENCE, ERROR, LEXERROR, VBAR, DOT, IDENT, PREDICATE, ACTION]);
        }
        break;
    case 52:
        switch (ddToken) {
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(27); // precedence_definitions: precedence_definitions precedence_definition
        default:
            return ddError([LEFT, RIGHT, NONASSOC, NEWSECTION]);
        }
        break;
    case 53:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 54:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 55:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        default:
            return ddError([LITERAL, IDENT]);
        }
        break;
    case 56:
        switch (ddToken) {
        case LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(25); // skip_definition: "%skip" REGEX
        default:
            return ddError([LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 57:
        switch (ddToken) {
        case TOKEN, FIELD:
            return ddReduce(8); // field_definition: "%field" fieldType fieldName fieldConversionFunction
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 58:
        switch (ddToken) {
        case TOKEN, FIELD:
            if ( !is_allowable_name(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(13); // fieldConversionFunction: IDENT ?(  !is_allowable_name($1.ddMatchedText)  ?)
            } else {
                return ddReduce(14); // fieldConversionFunction: IDENT
            }
        default:
            return ddError([TOKEN, FIELD]);
        }
        break;
    case 59:
        switch (ddToken) {
        case TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION:
            return ddReduce(18); // token_definition: "%token" FIELDNAME new_token_name pattern
        default:
            return ddError([TOKEN, LEFT, RIGHT, NONASSOC, SKIP, NEWSECTION]);
        }
        break;
    case 60:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(44); // production_tail_list: production_tail_list "|" production_tail
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 61:
        switch (ddToken) {
        case ACTION: return ddShift(28);
        case VBAR, DOT:
            return ddReduce(47); // production_tail: symbol_list predicate tagged_precedence
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 62:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(48); // production_tail: symbol_list predicate action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 63:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(50); // production_tail: symbol_list tagged_precedence action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 64:
        switch (ddToken) {
        case VBAR, DOT, ACTION:
            return ddReduce(56); // tagged_precedence: "%prec" IDENT
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 65:
        switch (ddToken) {
        case VBAR, DOT, ACTION:
            return ddReduce(57); // tagged_precedence: "%prec" LITERAL
        default:
            return ddError([VBAR, DOT, ACTION]);
        }
        break;
    case 66:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(28); // precedence_definition: "%left" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 67:
        switch (ddToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(31); // tag_list: tag
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 68:
        switch (ddToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(33); // tag: LITERAL
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 69:
        switch (ddToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            if ( symbolTable.is_known_token(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(34); // tag: IDENT ?(  symbolTable.is_known_token($1.ddMatchedText)  ?)
            } else if ( symbolTable.is_known_non_terminal(ddAttributeStack[$ - 2 + 1].ddMatchedText) ) {
                return ddReduce(35); // tag: IDENT ?(  symbolTable.is_known_non_terminal($1.ddMatchedText)  ?)
            } else {
                return ddReduce(36); // tag: IDENT
            }
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 70:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(29); // precedence_definition: "%right" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 71:
        switch (ddToken) {
        case LITERAL: return ddShift(68);
        case IDENT: return ddShift(69);
        case LEFT, RIGHT, NONASSOC, NEWSECTION:
            return ddReduce(30); // precedence_definition: "%nonassoc" tag_list
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    case 72:
        switch (ddToken) {
        case VBAR, DOT:
            return ddReduce(46); // production_tail: symbol_list predicate tagged_precedence action
        default:
            return ddError([VBAR, DOT]);
        }
        break;
    case 73:
        switch (ddToken) {
        case LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT:
            return ddReduce(32); // tag_list: tag_list tag
        default:
            return ddError([LITERAL, LEFT, RIGHT, NONASSOC, NEWSECTION, IDENT]);
        }
        break;
    default:
        throw new Exception(format("Invalid parser state: %s", ddCurrentState));
    }
    assert(false);
}

bool dd_error_recovery_ok(DDParserState ddParserState, DDToken ddToken)
{
    with (DDToken) switch(ddParserState) {
    default:
    }
    return false;
}

DDTokenSpec[] ddTokenSpecs;
static this() {
    ddTokenSpecs = [
        new DDTokenSpec(`REGEX`, `(\(.+\)(?=\s))`),
        new DDTokenSpec(`LITERAL`, `("\S+")`),
        new DDTokenSpec(`TOKEN`, `"%token"`),
        new DDTokenSpec(`FIELD`, `"%field"`),
        new DDTokenSpec(`LEFT`, `"%left"`),
        new DDTokenSpec(`RIGHT`, `"%right"`),
        new DDTokenSpec(`NONASSOC`, `"%nonassoc"`),
        new DDTokenSpec(`PRECEDENCE`, `"%prec"`),
        new DDTokenSpec(`SKIP`, `"%skip"`),
        new DDTokenSpec(`ERROR`, `"%error"`),
        new DDTokenSpec(`LEXERROR`, `"%lexerror"`),
        new DDTokenSpec(`NEWSECTION`, `"%%"`),
        new DDTokenSpec(`COLON`, `":"`),
        new DDTokenSpec(`VBAR`, `"|"`),
        new DDTokenSpec(`DOT`, `"."`),
        new DDTokenSpec(`IDENT`, `([a-zA-Z]+[a-zA-Z0-9_]*)`),
        new DDTokenSpec(`FIELDNAME`, `(<[a-zA-Z]+[a-zA-Z0-9_]*>)`),
        new DDTokenSpec(`PREDICATE`, `(\?\((.|[\n\r])*?\?\))`),
        new DDTokenSpec(`ACTION`, `(!\{(.|[\n\r])*?!\})`),
        new DDTokenSpec(`DCODE`, `(%\{(.|[\n\r])*?%\})`),
    ];
}

string[] ddSkipRules = [
        `(/\*(.|[\n\r])*?\*/)`,
        `(//[^\n\r]*)`,
        `(\s+)`,
    ];


mixin DDImplementParser;

