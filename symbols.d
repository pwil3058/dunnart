// symbols.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module symbols;

import std.string;
import std.regex;

import sets;
import idnumber;

import ddlib.lexan;

alias uint SymbolId;
enum SpecialSymbols : SymbolId { start, end, lexError, parseError };

enum SymbolType {token, tag, nonTerminal};

enum Associativity {nonassoc, left, right};

class FirstsData {
    Set!TokenSymbol tokenset;
    bool transparent;

    this(Set!TokenSymbol tokenset, bool transparent)
    {
        this.tokenset = tokenset;
        this.transparent = transparent;
    }

    override string toString()
    {
        return format("Firsts: %s; Transparent: %s", tokenset, transparent);
    }
}

alias uint Precedence;

bool is_allowable_name(string name)
{
    return name.length < 2 || (name[0 .. 2] != "dd" && name[0 .. 2] != "DD");
}

class Symbol {
    mixin IdNumber!(SymbolId);
    SymbolType type;
    string name;
    Associativity associativity;
    Precedence precedence;
    CharLocation definedAt;
    CharLocation[] usedAt;
    string fieldName;
    string pattern;
    FirstsData firstsData;

    this(SymbolId id, string sname, SymbolType stype, CharLocation location, bool isDefinition=true)
    {
        this.id = id;
        name = sname;
        type = stype;
        if (type == SymbolType.token) {
            // FIRST() for a token is trivial
            firstsData = new FirstsData(new Set!TokenSymbol(this), false);
        } else {
            firstsData = null;
        }
        if (isDefinition) {
            definedAt = location;
        } else {
            usedAt ~= location;
        }
    }

    @property
    bool is_defined()
    {
        return definedAt != CharLocation(0, 0);
    }

    @property
    bool is_used()
    {
        return usedAt.length > 0;
    }

    override string toString()
    {
        if (type == SymbolType.token && pattern.length > 0 && pattern[0] == '"') {
            return pattern;
        }
        return name;
    }
}

alias Symbol TokenSymbol;
alias Symbol TagSymbol;
alias Symbol NonTerminalSymbol;

struct FieldDefinition {
    string fieldName;
    string fieldType;
    string conversionFunctionName;
    CharLocation definedAt;
}

import std.stdio;

class SymbolTable {
    private SymbolId nextSymbolId;
    private static Symbol[SpecialSymbols.max + 1] specialSymbols;
    private TokenSymbol[string] tokens; // indexed by token name
    private TokenSymbol[string] literalTokens; // indexed by literal string
    private TagSymbol[string] tags; // indexed by name
    private NonTerminalSymbol[string] nonTerminals; // indexed by name
    private Symbol[SymbolId] allSymbols; // indexed by id
    private FieldDefinition[string] fieldDefinitions; // indexed by name
    private string[] skipRuleList;
    private auto currentPrecedence = Precedence.max;

    Symbol new_symbol(string sname, SymbolType stype, CharLocation location, bool isDefinition=true)
    {
        return new Symbol(nextSymbolId++, sname, stype, location, isDefinition);
    }

    static this()
    {
        specialSymbols[SpecialSymbols.start] = new Symbol(SpecialSymbols.start, "ddSTART", SymbolType.nonTerminal, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.end] = new Symbol(SpecialSymbols.end, "ddEND", SymbolType.token, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.lexError] = new Symbol(SpecialSymbols.lexError, "ddLEXERROR", SymbolType.token, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.parseError] = new Symbol(SpecialSymbols.parseError, "ddERROR", SymbolType.nonTerminal, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.parseError].firstsData = new FirstsData(new Set!Symbol, true);
        // ddLEXERROR looks like a token except that it's transparent
        specialSymbols[SpecialSymbols.lexError].firstsData = new FirstsData(new Set!Symbol(specialSymbols[SpecialSymbols.lexError]), true);
        for (auto i = SpecialSymbols.min; i <= SpecialSymbols.max; i++) {
            assert(specialSymbols[i].id == i);
        }
    }

    this()
    {
        for (auto i = SpecialSymbols.min; i <= SpecialSymbols.max; i++) {
            assert(i == nextSymbolId);
            allSymbols[i] = specialSymbols[i];
            nextSymbolId++;
        }
        assert(nextSymbolId == SpecialSymbols.max + 1);
    }

    TokenSymbol new_token(string newTokenName, string pattern, CharLocation location, string fieldName = "")
    in {
        assert(!is_known_symbol(newTokenName));
    }
    body {
        auto token = cast(TokenSymbol) new_symbol(newTokenName, SymbolType.token, location);
        token.pattern = pattern;
        token.fieldName = fieldName;
        tokens[newTokenName] = token;
        allSymbols[token.id] = token;
        if (pattern[0] == '"') {
            literalTokens[pattern] = token;
        }
        return token;
    }

    TagSymbol new_tag(string newTagName, CharLocation location)
    in {
        assert(!is_known_symbol(newTagName));
    }
    body {
        auto tag = cast(TagSymbol) new_symbol(newTagName, SymbolType.tag, location);
        tags[newTagName] = tag;
        allSymbols[tag.id] = tag;
        return tag;
    }

    @property
    size_t tokenCount()
    {
        return tokens.length;
    }

    @property
    size_t nonTerminalCount()
    {
        return nonTerminals.length;
    }

    bool is_known_token(string symbolName)
    {
        return (symbolName in tokens) !is null;
    }

    bool is_known_literal(string literal)
    {
        return (literal in literalTokens) !is null;
    }

    bool is_known_tag(string symbolName)
    {
        return (symbolName in tags) !is null;
    }

    bool
    is_known_non_terminal(string symbolName)
    {
        return (symbolName in nonTerminals) !is null;
    }

    bool is_known_symbol(string symbolName)
    {
        return symbolName in tokens || symbolName in tags || symbolName in nonTerminals;
    }

    Symbol get_symbol(string symbolName)
    {
        if (symbolName in tokens) {
            return tokens[symbolName];
        } else if (symbolName in nonTerminals) {
            return nonTerminals[symbolName];
        } else if (symbolName in tags) {
            return tags[symbolName];
        }
        return null;
    }

    Symbol get_special_symbol(SymbolId symbolId)
    {
        return specialSymbols[symbolId];
    }

    Symbol get_symbol(string symbolName, CharLocation location, bool autoCreate=false)
    {
        auto symbol = get_symbol(symbolName);
        if (symbol !is null) {
            symbol.usedAt ~= location;
        } else if (autoCreate) {
            // if it's referenced without being defined it's a non terminal
            symbol = cast(NonTerminalSymbol) new_symbol(symbolName, SymbolType.nonTerminal, location, false);
            nonTerminals[symbolName] = symbol;
            allSymbols[symbol.id] = symbol;
        }
        return symbol;
    }

    Symbol get_symbol(SymbolId symbolId)
    {
        return allSymbols.get(symbolId, null);
    }

    TokenSymbol get_literal_token(string literal, CharLocation location)
    {
        auto tokenSymbol = literalTokens.get(literal, null);
        if (tokenSymbol !is null) {
            tokenSymbol.usedAt ~= location;
        }
        return tokenSymbol;
    }

    CharLocation get_declaration_point(string symbolName)
    in {
        assert(is_known_symbol(symbolName));
    }
    body {
        if (symbolName in tokens) {
            return tokens[symbolName].definedAt;
        } else if (symbolName in nonTerminals) {
            return nonTerminals[symbolName].definedAt;
        } else if (symbolName in tags) {
            return tags[symbolName].definedAt;
        }
        assert(0);
    }

    void set_precedences(Associativity assoc, string[] symbolNames, CharLocation location)
    in {
        foreach (symbolName; symbolNames) {
            assert(!is_known_non_terminal(symbolName));
            assert(!is_known_tag(symbolName));
        }
    }
    body {
        foreach (symbolName; symbolNames) {
            auto symbol = tokens.get(symbolName, null);
            if (symbol is null) {
                symbol = new_tag(symbolName, location);
            }
            symbol.associativity = assoc;
            symbol.precedence = currentPrecedence;
        }
        currentPrecedence--;
    }

    void set_precedences(Associativity assoc, Symbol[] symbols)
    in {
        foreach (symbol; symbols) {
            assert(symbol.type != SymbolType.nonTerminal);
        }
    }
    body {
        foreach (symbol; symbols) {
            symbol.associativity = assoc;
            symbol.precedence = currentPrecedence;
        }
        currentPrecedence--;
    }

    void new_field(string fieldName, string fieldType, string convFuncName, CharLocation definedAt)
    in {
        assert(!is_known_field(fieldName));
    }
    body {
        fieldDefinitions[fieldName] = FieldDefinition(fieldName, fieldType, convFuncName);
    }

    bool is_known_field(string fieldName)
    {
        return (fieldName in fieldDefinitions) !is null;
    }

    void add_skip_rule(string newRule)
    in {
        assert(newRule.length > 3);
    }
    body {
        skipRuleList ~= newRule;
    }

    NonTerminalSymbol define_non_terminal(string symbolName, CharLocation location)
    in {
        assert(!is_known_token(symbolName) && !is_known_tag(symbolName));
        assert(!is_known_non_terminal(symbolName) || !nonTerminals[symbolName].is_defined());
    }
    body {
        auto symbol = nonTerminals.get(symbolName, null);
        if (symbol !is null) {
            symbol.definedAt = location;
        } else {
            symbol = cast(NonTerminalSymbol) new_symbol(symbolName, SymbolType.nonTerminal, location, true);
            nonTerminals[symbolName] = symbol;
            allSymbols[symbol.id] = symbol;
        }
        return symbol;
    }

    NonTerminalSymbol[] get_undefined_symbols()
    {
        NonTerminalSymbol[] undefined_symbols;
        foreach (nts; nonTerminals) {
            if (!nts.is_defined) {
                undefined_symbols ~= nts;
            }
        }
        return undefined_symbols;
    }

    Symbol[] get_unused_symbols()
    {
        Symbol[] unused_symbols;
        foreach (symbol; allSymbols) {
            if (!symbol.is_used && symbol.id > SpecialSymbols.max) {
                unused_symbols ~= symbol;
            }
        }
        return unused_symbols;
    }

    TokenSymbol[] get_tokens_ordered()
    {
        auto tokenset = new Set!TokenSymbol(tokens.values);
        return tokenset.elements;
    }

    TokenSymbol[] get_special_tokens_ordered()
    {
        auto tokenset = new Set!TokenSymbol;
        foreach (symbol; specialSymbols) {
            if (symbol.type == SymbolType.token) {
                tokenset.add(symbol);
            }
        }
        return tokenset.elements;
    }

    NonTerminalSymbol[] get_non_terminals_ordered()
    {
        auto symbolset = new Set!NonTerminalSymbol(nonTerminals.values);
        return symbolset.elements;
    }

    NonTerminalSymbol[] get_special_non_terminals_ordered()
    {
        auto symbolset = new Set!NonTerminalSymbol;
        foreach (symbol; specialSymbols) {
            if (symbol.type == SymbolType.nonTerminal) {
                symbolset.add(symbol);
            }
        }
        return symbolset.elements;
    }

    CharLocation get_field_defined_at(string fieldName)
    {
        return fieldDefinitions[fieldName].definedAt;
    }

    FieldDefinition[] get_field_definitions()
    {
        return fieldDefinitions.values;
    }

    string[] get_skip_rules()
    {
        return skipRuleList.dup;
    }

    string[] get_description()
    {
        auto textLines = ["Fields:"];
        if (fieldDefinitions.length == 0) {
            textLines ~= "  <none>";
        } else {
            foreach (key; extract_key_set(fieldDefinitions).elements) {
                with (fieldDefinitions[key]) {
                    if (conversionFunctionName.length == 0) {
                        textLines ~= format("  %s: %s: %s to!(%s)(string str)", fieldName, fieldType, fieldType, fieldType);
                    } else {
                        textLines ~= format("  %s: %s: %s %s(string str)", fieldName, fieldType, fieldType, conversionFunctionName);
                    }
                }
            }
        }
        textLines ~= "Tokens:";
        if (tokens.length == 0) {
            textLines ~= "  <none>";
        } else {
            foreach (token; get_tokens_ordered()) {
                with (token) {
                    textLines ~= format("  %s: %s: %s: %s: %s: %s", id, name, pattern, fieldName, associativity, precedence);
                    textLines ~= format("    Defined At: %s", definedAt);
                    textLines ~= format("    Used At: %s", usedAt);
                }
            }
        }
        textLines ~= "Precedence Tags:";
        if (tags.length == 0) {
            textLines ~= "  <none>";
        } else {
            foreach (tagKey; extract_key_set(tags).elements) {
                with (tags[tagKey]) {
                    textLines ~= format("  %s: %s: %s: %s", id, name, associativity, precedence);
                    textLines ~= format("    Defined At: %s", definedAt);
                    textLines ~= format("    Used At: %s", usedAt);
                }
            }
        }
        textLines ~= "Non Terminal Symbols:";
        if (nonTerminals.length == 0) {
            textLines ~= "  <none>";
        } else {
            foreach (nonTerminal; get_non_terminals_ordered()) {
                with (nonTerminal) {
                    textLines ~= format("  %s: %s:", id, name);
                    textLines ~= format("    Defined At: %s", definedAt);
                    textLines ~= format("    Used At: %s", usedAt);
                }
            }
        }
        return textLines;
    }
}

unittest {
    auto st = new SymbolTable;
}
