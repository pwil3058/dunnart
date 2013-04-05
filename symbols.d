module symbols;

import std.string;
import std.regex;

import sets;
import idnumber;

import ddlib.lexan;
//import ddlib.components;

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
    return name.length < 2 || toLower(name[0 .. 2]) != "dd";
}

// TODO: reimplement Symbol generation with a factory so that each
// TODO: SymbolTable's symbols can be sequential from zero
// TODO: Or maybe not -- only needed for bootstrapping ??
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
        assert(next_id <= SpecialSymbols.max);
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
}

import std.stdio;

class SymbolTable {
    private static Symbol[SpecialSymbols.max + 1] specialSymbols;
    private TokenSymbol[string] tokens; // indexed by token name
    private TokenSymbol[string] literalTokens; // indexed by literal string
    private TagSymbol[string] tags; // indexed by name
    private NonTerminalSymbol[string] nonTerminals; // indexed by name
    private Symbol[SymbolId] allSymbols; // indexed by id
    private FieldDefinition[string] fieldDefinitions; // indexed by name
    private string[] skipRuleList;
    private auto currentPrecedence = Precedence.max;

    static this()
    {
        specialSymbols[SpecialSymbols.start] = new Symbol("ddSTART", SymbolType.nonTerminal, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.end] = new Symbol("ddEND", SymbolType.token, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.lexError] = new Symbol("ddLEXERROR", SymbolType.token, CharLocation(0, 0));
        specialSymbols[SpecialSymbols.parseError] = new Symbol("ddERROR", SymbolType.nonTerminal, CharLocation(0, 0));
        // TODO: think about whether this is the correct FirstsData for ddERROR
        // It's definitely transparent but should the tokenSet be all tokens or none?
        specialSymbols[SpecialSymbols.parseError].firstsData = new FirstsData(new Set!Symbol, true);
        for (auto i = SpecialSymbols.min; i <= SpecialSymbols.max; i++) {
            assert(specialSymbols[i].id == i);
        }
        assert(Symbol.next_id == SpecialSymbols.max + 1);
    }

    this()
    {
        foreach (symbol; specialSymbols) {
            allSymbols[symbol.id] = symbol;
        }
    }

    TokenSymbol new_token(string newTokenName, string pattern, CharLocation location, string fieldName = "")
    in {
        assert(!is_known_symbol(newTokenName));
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

    TagSymbol new_tag(string newTagName, CharLocation location)
    in {
        assert(!is_known_symbol(newTagName));
    }
    body {
        auto tag = new TagSymbol(newTagName, SymbolType.tag, location);
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
            symbol = new NonTerminalSymbol(symbolName, SymbolType.nonTerminal, location, false);
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

    void new_field(string fieldName, string fieldType, string convFuncName = "")
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
            symbol = new NonTerminalSymbol(symbolName, SymbolType.nonTerminal, location, true);
            nonTerminals[symbolName] = symbol;
            allSymbols[symbol.id] = symbol;
        }
        return symbol;
    }

    NonTerminalSymbol[] get_undefined_symbols()
    {
        NonTerminalSymbol[] undefined_symbols;
        foreach (nts; nonTerminals) {
            if (nts.definedAt == CharLocation(0,0)) {
                undefined_symbols ~= nts;
            }
        }
        return undefined_symbols;
    }

    Symbol[] get_unused_symbols()
    {
        Symbol[] unused_symbols;
        foreach (symbol; allSymbols) {
            if (symbol.usedAt.length == 0 && symbol.id > SpecialSymbols.max) {
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

    FieldDefinition[] get_field_definitions()
    {
        return fieldDefinitions.values;
    }

    string[] get_skip_rules()
    {
        return skipRuleList.dup;
    }
}

unittest {
    auto st = new SymbolTable;
}
