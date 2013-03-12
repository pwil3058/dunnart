module symbols;

import ddlib.lexan;
import ddlib.components;

enum SymbolType {token, tag, nonterminal};

enum Associativity {nonassoc, left, right};

class Symbol {
    static SymbolId next_id = SpecialSymbols.max + 1;
    SymbolId id;
    SymbolType type;
    string name;
    Associativity associativity;
    uint precedence;
    CharLocation definedAt;
    CharLocation[] usedAt;
    string fieldName;
    string pattern;

    this(string sname, SymbolType stype, CharLocation location, bool isDefinition=true)
    {
        id = next_id++;
        name = sname;
        type = stype;
        if (isDefinition) {
            definedAt = location;
        } else {
            usedAt ~= location;
        }
    }

    override hash_t
    toHash()
    {
        return id;
    }

    override bool
    opEquals(Object o)
    {
        Symbol other = cast(Symbol) o;
        return other && id == other.id;
    }

    override int
    opCmp(Object o)
    {
        Symbol other = cast(Symbol) o;
        return other ? id - other.id : -1;
    }
}

alias Symbol TokenSymbol;
alias Symbol TagSymbol;
alias Symbol NonterminalSymbol;

class SymbolManager {
    private TokenSymbol[string] tokens; // indexed by token name
    private TokenSymbol[string] literalTokens; // indexed by literal string
    private TagSymbol[string] tags; // indexed by name
    private NonterminalSymbol[string] nonTerminals; // indexed by name
    private Symbol[SymbolId] allSymbols; // indexed by id
    //private FieldDefinition[string] fieldDefinitions; // indexed by name
    private string[] skipList;
    private auto currentPrecedence = uint.max;

    TokenSymbol
    new_token(string newTokenName, string pattern, CharLocation location, string fieldName = "")
    {
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
    is_known_symbol(string symbolName)
    {
        return symbolName in tokens || symbolName in tags || symbolName in nonTerminals;
    }

    CharLocation
    get_declaration_point(string symbolName)
    {
        if (symbolName in tokens) {
            return tokens[symbolName].definedAt;
        } else if (symbolName in nonTerminals) {
            return nonTerminals[symbolName].definedAt;
        } else if (symbolName in tags) {
            return tags[symbolName].definedAt;
        }
        assert(0);
    }
}
