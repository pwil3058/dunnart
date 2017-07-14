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
import workarounds;
import workarounds: wa_sort;

import ddlib.lexan;

alias uint SymbolId;
enum SpecialSymbols : SymbolId { start, end, invalid_token, parse_error };

enum SymbolType {token, tag, non_terminal};

enum Associativity {nonassoc, left, right};
alias uint Precedence;
struct AssociativePrecedence {
    Associativity associativity;
    Precedence    precedence;

    @property
    bool is_explicitly_set()
    {
        return precedence != 0;
    }
}

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

bool is_allowable_name(string name)
{
    return name.length < 2 || (name[0..2] != "dd" && name[0..2] != "DD");
}

class Symbol {
    mixin IdNumber!(SymbolId);
    const SymbolType type;
    const string name;
    AssociativePrecedence associative_precedence;
    CharLocation defined_at;
    CharLocation[] used_at;
    string field_name;
    string pattern;
    FirstsData firsts_data;

    this(SymbolId id, string sname, SymbolType stype, CharLocation location, bool is_definition=true)
    {
        this.id = id;
        name = sname;
        type = stype;
        if (type == SymbolType.token) {
            // FIRST() for a token is trivial
            firsts_data = new FirstsData(Set!TokenSymbol(this), false);
        } else {
            firsts_data = null;
        }
        if (is_definition) {
            defined_at = location;
        } else {
            used_at ~= location;
        }
    }

    @property
    Associativity associativity()
    {
        return associative_precedence.associativity;
    }

    @property
    Precedence precedence()
    {
        return associative_precedence.precedence;
    }

    @property
    bool is_defined()
    {
        return defined_at != CharLocation(0, 0);
    }

    @property
    bool is_used()
    {
        return used_at.length > 0;
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
    string field_name;
    string field_type;
    string conversion_function_name;
    CharLocation defined_at;
}

import std.stdio;

struct SymbolTable {
    private SymbolId next_symbol_id = SpecialSymbols.max + 1;
    private static Symbol[SpecialSymbols.max + 1] special_symbols;
    private TokenSymbol[string] tokens; // indexed by token name
    private TokenSymbol[string] literal_tokens; // indexed by literal string
    private TagSymbol[string] tags; // indexed by name
    private NonTerminalSymbol[string] non_terminals; // indexed by name
    private FieldDefinition[string] field_definitions; // indexed by name
    private string[] skip_rule_list;
    private auto current_precedence = Precedence.max;

    invariant () {
        import std.stdio;
        auto check_sum = 0; // Sum of arithmetic series
        for (auto i = SpecialSymbols.min; i <= SpecialSymbols.max; i++) {
            assert(special_symbols[i].id == i);
            check_sum += i;
        }
        assert(next_symbol_id == (SpecialSymbols.max + tokens.length + tags.length + non_terminals.length + 1));
        foreach (literal; literal_tokens.keys) {
            auto literal_token = literal_tokens[literal];
            assert(literal_token.pattern == literal);
            assert(tokens[literal_token.name] is literal_token);
        }
        foreach (key; tokens.byKey()) {
            auto token = tokens[key];
            assert(token.name == key && token.type == SymbolType.token);
            assert(token.pattern[0] == '"' ? literal_tokens[token.pattern] is token : token.pattern !in literal_tokens);
            assert(token.id > SpecialSymbols.max && token.id < next_symbol_id);
            check_sum += token.id;
        }
        foreach (key; tags.byKey()) {
            auto tag = tags[key];
            assert(tag.name == key && tag.type == SymbolType.tag);
            assert(tag.id > SpecialSymbols.max && tag.id < next_symbol_id);
            check_sum += tag.id;
        }
        foreach (key; non_terminals.byKey()) {
            auto non_terminal = non_terminals[key];
            assert(non_terminal.name == key && non_terminal.type == SymbolType.non_terminal);
            assert(non_terminal.id > SpecialSymbols.max && non_terminal.id < next_symbol_id);
            check_sum += non_terminal.id;
        }
        assert(check_sum == ((next_symbol_id * (next_symbol_id - 1)) / 2));
    }

    static this()
    {
        special_symbols[SpecialSymbols.start] = new Symbol(SpecialSymbols.start, "ddSTART", SymbolType.non_terminal, CharLocation(0, 0));
        special_symbols[SpecialSymbols.end] = new Symbol(SpecialSymbols.end, "ddEND", SymbolType.token, CharLocation(0, 0));
        special_symbols[SpecialSymbols.invalid_token] = new Symbol(SpecialSymbols.invalid_token, "ddINVALID_TOKEN", SymbolType.token, CharLocation(0, 0));
        special_symbols[SpecialSymbols.parse_error] = new Symbol(SpecialSymbols.parse_error, "ddERROR", SymbolType.non_terminal, CharLocation(0, 0));
        special_symbols[SpecialSymbols.parse_error].firsts_data = new FirstsData(Set!Symbol(), true);
    }

    TokenSymbol new_token(string new_token_name, string pattern, CharLocation location, string field_name = "")
    in {
        assert(!is_known_symbol(new_token_name));
    }
    body {
        auto token = cast(TokenSymbol) new Symbol(next_symbol_id++, new_token_name, SymbolType.token, location);
        token.pattern = pattern;
        token.field_name = field_name;
        tokens[new_token_name] = token;
        if (pattern[0] == '"') {
            literal_tokens[pattern] = token;
        }
        return token;
    }

    TagSymbol new_tag(string new_tag_name, CharLocation location)
    in {
        assert(!is_known_symbol(new_tag_name));
    }
    body {
        auto tag = cast(TagSymbol) new Symbol(next_symbol_id++, new_tag_name, SymbolType.tag, location);
        tags[new_tag_name] = tag;
        return tag;
    }

    @property
    size_t token_count()
    {
        return tokens.length;
    }

    @property
    size_t non_terminal_count()
    {
        return non_terminals.length;
    }

    bool is_known_token(string symbol_name)
    {
        return (symbol_name in tokens) !is null;
    }

    bool is_known_literal(string literal)
    {
        return (literal in literal_tokens) !is null;
    }

    bool is_known_tag(string symbol_name)
    {
        return (symbol_name in tags) !is null;
    }

    bool
    is_known_non_terminal(string symbol_name)
    {
        return (symbol_name in non_terminals) !is null;
    }

    bool is_known_symbol(string symbol_name)
    {
        return symbol_name in tokens || symbol_name in tags || symbol_name in non_terminals;
    }

    Symbol get_symbol(string symbol_name)
    {
        if (symbol_name in tokens) {
            return tokens[symbol_name];
        } else if (symbol_name in non_terminals) {
            return non_terminals[symbol_name];
        } else if (symbol_name in tags) {
            return tags[symbol_name];
        }
        return null;
    }

    Symbol get_special_symbol(SymbolId symbol_id)
    {
        return special_symbols[symbol_id];
    }

    Symbol get_symbol(string symbol_name, CharLocation location, bool auto_create=false)
    {
        auto symbol = get_symbol(symbol_name);
        if (symbol !is null) {
            symbol.used_at ~= location;
        } else if (auto_create) {
            // if it's referenced without being defined it's a non terminal
            symbol = cast(NonTerminalSymbol) new Symbol(next_symbol_id++, symbol_name, SymbolType.non_terminal, location, false);
            non_terminals[symbol_name] = symbol;
        }
        return symbol;
    }

    TokenSymbol get_literal_token(string literal, CharLocation location)
    {
        auto token_symbol = literal_tokens.get(literal, null);
        if (token_symbol !is null) {
            token_symbol.used_at ~= location;
        }
        return token_symbol;
    }

    CharLocation get_declaration_point(string symbol_name)
    in {
        assert(is_known_symbol(symbol_name));
    }
    body {
        if (symbol_name in tokens) {
            return tokens[symbol_name].defined_at;
        } else if (symbol_name in non_terminals) {
            return non_terminals[symbol_name].defined_at;
        } else if (symbol_name in tags) {
            return tags[symbol_name].defined_at;
        }
        assert(0);
    }

    void set_precedences(Associativity assoc, string[] symbol_names, CharLocation location)
    in {
        foreach (symbol_name; symbol_names) {
            assert(!is_known_non_terminal(symbol_name));
            assert(!is_known_tag(symbol_name));
        }
    }
    body {
        foreach (symbol_name; symbol_names) {
            auto symbol = tokens.get(symbol_name, null);
            if (symbol is null) {
                symbol = new_tag(symbol_name, location);
            }
            symbol.associative_precedence = AssociativePrecedence(assoc, current_precedence);
        }
        current_precedence--;
    }

    void set_precedences(Associativity assoc, Symbol[] symbols)
    in {
        foreach (symbol; symbols) {
            assert(symbol.type != SymbolType.non_terminal);
        }
    }
    body {
        foreach (symbol; symbols) {
            symbol.associative_precedence = AssociativePrecedence(assoc, current_precedence);
        }
        current_precedence--;
    }

    void new_field(string field_name, string field_type, string conv_func_name, CharLocation defined_at)
    in {
        assert(!is_known_field(field_name));
    }
    body {
        field_definitions[field_name] = FieldDefinition(field_name, field_type, conv_func_name);
    }

    bool is_known_field(string field_name)
    {
        return (field_name in field_definitions) !is null;
    }

    void add_skip_rule(string new_rule)
    in {
        assert(new_rule.length > 3);
    }
    body {
        skip_rule_list ~= new_rule;
    }

    NonTerminalSymbol define_non_terminal(string symbol_name, CharLocation location)
    in {
        assert(!is_known_token(symbol_name) && !is_known_tag(symbol_name));
        assert(!is_known_non_terminal(symbol_name) || !non_terminals[symbol_name].is_defined());
    }
    body {
        auto symbol = non_terminals.get(symbol_name, null);
        if (symbol !is null) {
            symbol.defined_at = location;
        } else {
            symbol = cast(NonTerminalSymbol) new Symbol(next_symbol_id++, symbol_name, SymbolType.non_terminal, location, true);
            non_terminals[symbol_name] = symbol;
        }
        return symbol;
    }

    NonTerminalSymbol[] get_undefined_symbols()
    {
        NonTerminalSymbol[] undefined_symbols;
        foreach (nts; non_terminals) {
            if (!nts.is_defined) {
                undefined_symbols ~= nts;
            }
        }
        return undefined_symbols;
    }

    Symbol[] get_unused_symbols()
    {
        Symbol[] unused_symbols;
        foreach (symbols; [tokens, tags, non_terminals]) {
            foreach (symbol; symbols) {
                if (!symbol.is_used) {
                    unused_symbols ~= symbol;
                }
            }
        }
        return unused_symbols;
    }

    TokenSymbol[] get_tokens_ordered()
    out (result) {
        mixin WorkAroundClassCmpLimitations!TokenSymbol;
        for (auto i = 0; i < result.length; i++) {
            if (i > 0) assert(WA_CMP_ECAST(result[i -1]) < WA_CMP_ECAST(result[i]));
            assert(result[i].type == SymbolType.token);
        }
        assert(result.length == tokens.length);
    }
    body {
        return tokens.values.wa_sort;
    }

    TokenSymbol[] get_special_tokens_ordered()
    out (result) {
        mixin WorkAroundClassCmpLimitations!TokenSymbol;
        for (auto i = 0; i < result.length; i++) {
            if (i > 0) assert(WA_CMP_ECAST(result[i -1]) < WA_CMP_ECAST(result[i]));
            assert(result[i].type == SymbolType.token);
            assert(result[i].id >= SpecialSymbols.min);
            assert(result[i].id <= SpecialSymbols.max);
        }
    }
    body {
        // special_symbols is ordered so just pick the tokens
        TokenSymbol[] special_tokens_ordered;
        foreach (symbol; special_symbols) {
            if (symbol.type == SymbolType.token) {
                special_tokens_ordered ~= symbol;
            }
        }
        return special_tokens_ordered;
    }

    NonTerminalSymbol[] get_non_terminals_ordered()
    out (result) {
        mixin WorkAroundClassCmpLimitations!TokenSymbol;
        for (auto i = 0; i < result.length; i++) {
            if (i > 0) assert(WA_CMP_ECAST(result[i -1]) < WA_CMP_ECAST(result[i]));
            assert(result[i].type == SymbolType.non_terminal);
        }
        assert(result.length == non_terminals.length);
    }
    body {
        return non_terminals.values.wa_sort;
    }

    NonTerminalSymbol[] get_special_non_terminals_ordered()
    out (result) {
        mixin WorkAroundClassCmpLimitations!TokenSymbol;
        for (auto i = 0; i < result.length; i++) {
            if (i > 0) assert(WA_CMP_ECAST(result[i -1]) < WA_CMP_ECAST(result[i]));
            assert(result[i].type == SymbolType.non_terminal);
            assert(result[i].id >= SpecialSymbols.min);
            assert(result[i].id <= SpecialSymbols.max);
        }
    }
    body {
        NonTerminalSymbol[] special_non_terminals;
        foreach (symbol; special_symbols) {
            if (symbol.type == SymbolType.non_terminal) {
                special_non_terminals ~= symbol;
            }
        }
        return special_non_terminals;
    }

    CharLocation get_field_defined_at(string field_name)
    {
        return field_definitions[field_name].defined_at;
    }

    FieldDefinition[] get_field_definitions()
    {
        return field_definitions.values;
    }

    string[] get_skip_rules()
    {
        return skip_rule_list.dup;
    }

    string[] get_description()
    {
        auto text_lines = ["Fields:"];
        if (field_definitions.length == 0) {
            text_lines ~= "  <none>";
        } else {
            foreach (key; field_definitions.keys.wa_sort) {
                with (field_definitions[key]) {
                    if (conversion_function_name.length == 0) {
                        text_lines ~= format("  %s: %s: %s to!(%s)(string str)", field_name, field_type, field_type, field_type);
                    } else {
                        text_lines ~= format("  %s: %s: %s %s(string str)", field_name, field_type, field_type, conversion_function_name);
                    }
                }
            }
        }
        text_lines ~= "Tokens:";
        if (tokens.length == 0) {
            text_lines ~= "  <none>";
        } else {
            foreach (token; get_tokens_ordered()) {
                with (token) {
                    text_lines ~= format("  %s: %s: %s: %s: %s: %s", id, name, pattern, field_name, associativity, precedence);
                    text_lines ~= format("    Defined At: %s", defined_at);
                    text_lines ~= format("    Used At: %s", used_at);
                }
            }
        }
        text_lines ~= "Precedence Tags:";
        if (tags.length == 0) {
            text_lines ~= "  <none>";
        } else {
            foreach (tagKey; tags.keys.wa_sort) {
                with (tags[tagKey]) {
                    text_lines ~= format("  %s: %s: %s: %s", id, name, associativity, precedence);
                    text_lines ~= format("    Defined At: %s", defined_at);
                    text_lines ~= format("    Used At: %s", used_at);
                }
            }
        }
        text_lines ~= "Non Terminal Symbols:";
        if (non_terminals.length == 0) {
            text_lines ~= "  <none>";
        } else {
            foreach (non_terminal; get_non_terminals_ordered()) {
                with (non_terminal) {
                    text_lines ~= format("  %s: %s:", id, name);
                    text_lines ~= format("    Defined At: %s", defined_at);
                    text_lines ~= format("    Used At: %s", used_at);
                }
            }
        }
        return text_lines;
    }
}

unittest {
    auto st = SymbolTable();
    assert(st.get_special_symbol(SpecialSymbols.start).name == "ddSTART");
}
