module symbols;

import std.string;

import sets;
import idnumber;

import ddlib.lexan;
import ddlib.components;

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
}

alias uint Precedence;

bool
is_allowable_name(string name)
{
    return name.length < 2 || toLower(name[0 .. 2]) != "dd";
}

class Symbol {
    mixin UniqueId!(SymbolId);
    SymbolType type;
    string name;
    Associativity associativity;
    Precedence precedence;
    CharLocation definedAt;
    CharLocation[] usedAt;
    string fieldName;
    string pattern;
    FirstsData firstsData;

    this(string sname, SymbolType stype, CharLocation location, bool isDefinition=true)
    in {
        assert(next_id <= SpecialSymbols.max || is_allowable_name(sname));
    }
    body {
        mixin(set_unique_id);
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

    @property bool
    is_defined()
    {
        return definedAt != CharLocation(0, 0);
    }

    @property bool
    is_used()
    {
        return usedAt.length > 0;
    }
}

alias Symbol TokenSymbol;
alias Symbol TagSymbol;
alias Symbol NonTerminalSymbol;

class SymbolTable {
    private TokenSymbol[string] tokens; // indexed by token name
    private TokenSymbol[string] literalTokens; // indexed by literal string
    private TagSymbol[string] tags; // indexed by name
    private NonTerminalSymbol[string] nonTerminals; // indexed by name
    private Symbol[SymbolId] allSymbols; // indexed by id
    private FieldDefinition[string] fieldDefinitions; // indexed by name
    private string[] skipRuleList;
    private auto currentPrecedence = Precedence.max;

    this() {
        allSymbols[SpecialSymbols.start] = new Symbol("ddSTART", SymbolType.nonTerminal, CharLocation(0, 0));
        allSymbols[SpecialSymbols.end] = new Symbol("ddEND", SymbolType.token, CharLocation(0, 0));
        allSymbols[SpecialSymbols.lexError] = new Symbol("ddLEXERROR", SymbolType.token, CharLocation(0, 0));
        allSymbols[SpecialSymbols.parseError] = new Symbol("ddERROR", SymbolType.nonTerminal, CharLocation(0, 0));
        // TODO: think about whether this is the correct FirstsData for ddERROR
        // It's definitely transparent but should the tokenSet be all tokens or none?
        allSymbols[SpecialSymbols.parseError].firstsData = new FirstsData(new Set!Symbol, true);
        for (auto i = SpecialSymbols.min; i <= SpecialSymbols.max; i++) {
            assert(allSymbols[i].id == i);
        }
        assert(Symbol.next_id == SpecialSymbols.max + 1);
    }

    TokenSymbol
    new_token(string newTokenName, string pattern, CharLocation location, string fieldName = "")
    in {
        assert(!is_known_symbol(newTokenName));
        assert(is_allowable_name(newTokenName));
    }
    body {
        auto token = new TokenSymbol(newTokenName, SymbolType.token, location);
        token.pattern = pattern;
        token.fieldName = fieldName;
        tokens[newTokenName] = token;
        allSymbols[token.id] = token;
        if (pattern[0] == '"') {
            literalTokens[pattern] = token;
        }
        return token;
    }

    bool
    is_known_token(string symbolName)
    {
        return (symbolName in tokens) !is null;
    }

    bool
    is_known_literal(string literal)
    {
        return (literal in literalTokens) !is null;
    }

    bool
    is_known_tag(string symbolName)
    {
        return (symbolName in tags) !is null;
    }

    bool
    is_known_non_terminal(string symbolName)
    {
        return (symbolName in nonTerminals) !is null;
    }

    bool
    is_known_symbol(string symbolName)
    {
        return symbolName in tokens || symbolName in tags || symbolName in nonTerminals;
    }

    Symbol
    get_symbol(string symbolName)
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

    Symbol
    get_symbol(string symbolName, CharLocation location, bool autoCreate=false)
    in {
        assert(!autoCreate || is_allowable_name(symbolName));
    }
    body {
        auto symbol = get_symbol(symbolName);
        if (symbol !is null) {
            symbol.usedAt ~= location;
        } else if (autoCreate) {
            // if it's referenced without being defined it's a non terminal
            symbol = new NonTerminalSymbol(symbolName, SymbolType.nonTerminal, location, false);
        }
        return symbol;
    }

    Symbol
    get_symbol(SymbolId symbolId)
    {
        return allSymbols.get(symbolId, null);
    }

    TokenSymbol
    get_literal_token(string literal, CharLocation location)
    {
        auto tokenSymbol = literalTokens.get(literal, null);
        if (tokenSymbol !is null) {
            tokenSymbol.usedAt ~= location;
        }
        return tokenSymbol;
    }

    CharLocation
    get_declaration_point(string symbolName)
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

    void
    set_precedences(Associativity assoc, string[] symbolNames, CharLocation location)
    in {
        foreach (symbolName; symbolNames) {
            assert(!is_known_non_terminal(symbolName));
            assert(!is_known_tag(symbolName));
            assert(is_allowable_name(symbolName));
        }
    }
    body {
        foreach (symbolName; symbolNames) {
            auto symbol = tokens.get(symbolName, null);
            if (symbol is null) {
                symbol = new Symbol(symbolName, SymbolType.tag, location);
                tags[symbolName] = symbol;
                allSymbols[symbol.id] = symbol;
            }
            symbol.associativity = assoc;
            symbol.precedence = currentPrecedence;
        }
        currentPrecedence--;
    }

    void
    new_field(string fieldName, string fieldType, string convFuncName = "")
    in {
        assert(!is_known_field(fieldName));
        assert(is_allowable_name(fieldName));
        assert(is_allowable_name(fieldType));
        assert(is_allowable_name(convFuncName));
    }
    body {
        fieldDefinitions[fieldName] = FieldDefinition(fieldName, fieldType, convFuncName);
    }

    bool
    is_known_field(string fieldName)
    {
        return (fieldName in fieldDefinitions) !is null;
    }

    void
    add_skip_rule(string newRule)
    in {
        assert(newRule.length > 3);
    }
    body {
        skipRuleList ~= newRule;
    }

    NonTerminalSymbol
    define_non_terminal(string symbolName, CharLocation location)
    in {
        assert(!is_known_token(symbolName) && !is_known_tag(symbolName));
        assert(!is_known_non_terminal(symbolName) || !nonTerminals[symbolName].is_defined());
    }
    body {
        auto symbol = nonTerminals.get(symbolName, null);
        if (symbol !is null) {
            symbol.definedAt = location;
        } else {
            symbol = new NonTerminalSymbol(symbolName, SymbolType.nonTerminal, location, true);
        }
        return symbol;
    }
}

unittest {
    auto st = new SymbolTable;
}
