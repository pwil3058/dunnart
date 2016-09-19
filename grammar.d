// grammar.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module grammar;

import std.string;
import std.regex;
import std.stdio;

import symbols;
import sets;
import idnumber;

alias uint ProductionId;
alias string Predicate;
alias string SemanticAction;

class Production {
    mixin IdNumber!(ProductionId);
    NonTerminalSymbol left_hand_side;
    Symbol[] right_hand_side;
    Predicate predicate;
    SemanticAction action;
    AssociativePrecedence associative_precedence;

    this(ProductionId id, NonTerminalSymbol lhs, Symbol[] rhs, Predicate pred, SemanticAction actn, AssociativePrecedence aprec)
    {
        this.id = id;
        left_hand_side = lhs;
        right_hand_side = rhs;
        predicate = pred;
        action = actn;
        if (aprec.is_explicitly_set) {
            associative_precedence = aprec;
        } else {
            for (int i = cast(int) rhs.length - 1; i >= 0; i--) {
                auto symbol = rhs[i];
                if (symbol.type == SymbolType.token && symbol.associative_precedence.is_explicitly_set) {
                    // We only inherit precedence/associativity if it's been explicitly set for the token
                    associative_precedence = symbol.associative_precedence;
                    break;
                }
            }
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
    const size_t length()
    {
        return right_hand_side.length;
    }

    @property
    string expanded_predicate()
    {
        static auto stack_attr_re = regex(r"\$(\d+)", "g");
        static auto next_token_re = regex(r"\$#", "g");
        auto replaceWith = format("dd_attribute_stack[$$ - %s + $1]", right_hand_side.length + 1);
        return replace(replace(predicate, stack_attr_re, replaceWith), next_token_re, "dd_next_token");
    }

    @property
    string[] expanded_semantic_action()
    {
        static auto lhs_re = regex(r"\$\$", "g");
        static auto stack_attr_re = regex(r"\$(\d+)", "g");
        size_t last_non_blank_line_index = 0;
        size_t first_non_blank_line_index = 0;
        auto non_blank_line_seen = false;
        string[] first_pass_lines;
        foreach (index, line; replace(replace(action, lhs_re, "dd_lhs"), stack_attr_re, "dd_args[$1 - 1]").splitLines) {
            string strippedLine = line.stripRight.detab(4);
            if (strippedLine.length > 0) {
                last_non_blank_line_index = index;
                if (!non_blank_line_seen) first_non_blank_line_index = index;
                non_blank_line_seen = true;
            }
            first_pass_lines ~= strippedLine;
        }
        auto required_indent = "        ";
        string[] second_pass_lines;
        foreach (line; first_pass_lines[first_non_blank_line_index..last_non_blank_line_index + 1].outdent) {
            second_pass_lines ~= required_indent ~ line;
        }
        return second_pass_lines;
    }

    override string toString()
    {
        // This is just for use in generated code comments
        if (right_hand_side.length == 0) {
            return format("%s: <empty>", left_hand_side.name);
        }
        auto str = format("%s:", left_hand_side.name);
        foreach (symbol; right_hand_side) {
            str ~= format(" %s", symbol);
        }
        if (predicate.length > 0) {
            str ~= format(" ?( %s ?)", predicate);
        }
        return str;
    }

    @property
    bool has_error_recovery_tail()
    {
        if (right_hand_side.length == 0) return false;
        auto last_symbol_id = right_hand_side[$ - 1].id;
        return last_symbol_id == SpecialSymbols.parse_error;
    }
}

struct GrammarItemKey {
    Production production;
    uint dot;
    invariant () {
        assert(dot <= production.length);
    }

    this(Production production, uint dot=0)
    {
        this.production = production;
        this.dot = dot;
    }

    GrammarItemKey clone_shifted()
    in {
        assert(dot < production.length);
    }
    out (result) {
        assert(result.dot == dot + 1);
        assert(result.production is production);
    }
    body {
        return GrammarItemKey(production, dot + 1);
    }

    @property
    bool is_reducible()
    {
        return dot == production.length;
    }

    @property
    bool is_kernel_item()
    {
        return dot > 0 || production.left_hand_side.id == SpecialSymbols.start;
    }

    @property
    bool is_closable()
    {
        return dot < production.length && production.right_hand_side[dot].type == SymbolType.non_terminal;
    }

    @property
    Symbol next_symbol()
    in {
        assert(dot < production.length);
    }
    body {
        return production.right_hand_side[dot];
    }

    @property
    Symbol[] tail()
    in {
        assert(dot < production.length);
    }
    body {
        return production.right_hand_side[dot + 1..$];
    }

    bool next_symbol_is(Symbol symbol)
    {
        return dot < production.length && production.right_hand_side[dot] == symbol;
    }

    hash_t toHash() const
    {
        return production.id * (dot + 1);
    }

    bool opEquals(const GrammarItemKey other) const
    {
        return production.id == other.production.id && dot == other.dot;
    }

    int opCmp(const GrammarItemKey other) const
    {
        if (production.id == other.production.id) {
            return dot - other.dot;
        }
        return production.id - other.production.id;
    }

    string toString()
    {
        with (production) {
            // This is just for use in debugging
            if (right_hand_side.length == 0) {
                return format("%s: . <empty>", left_hand_side.name);
            }
            auto str = format("%s:", left_hand_side.name);
            for (auto i = 0; i < right_hand_side.length; i++) {
                if (i == dot) {
                    str ~= " .";
                }
                str ~= format(" %s", right_hand_side[i]);
            }
            if (dot == right_hand_side.length) {
                str ~= " .";
            }
            if (predicate.length > 0) {
                str ~= format(" ?( %s ?)", predicate);
            }
            return str;
        }
    }
}

alias Set!(TokenSymbol)[GrammarItemKey] GrammarItemSet;

Set!GrammarItemKey get_kernel_keys(GrammarItemSet itemset)
{
    auto key_set = Set!GrammarItemKey();
    foreach (grammar_item_key; itemset.byKey()) {
        if (grammar_item_key.is_kernel_item) {
            key_set += grammar_item_key;
        }
    }
    return key_set;
}

Set!GrammarItemKey get_reducible_keys(GrammarItemSet itemset)
{
    auto key_set = Set!GrammarItemKey();
    foreach (grammar_item_key, look_ahead_set; itemset) {
        if (grammar_item_key.is_reducible) {
            key_set += grammar_item_key;
        }
    }
    return key_set;
}

GrammarItemSet generate_goto_kernel(GrammarItemSet itemset, Symbol symbol)
{
    GrammarItemSet goto_kernel;
    foreach (grammar_item_key, look_ahead_set; itemset) {
        if (grammar_item_key.next_symbol_is(symbol)) {
            goto_kernel[grammar_item_key.clone_shifted()] = look_ahead_set.clone();
        }
    }
    return goto_kernel;
}

enum ProcessedState { unprocessed, needs_reprocessing, processed };

struct ShiftReduceConflict {
    TokenSymbol shift_symbol;
    ParserState goto_state;
    GrammarItemKey reducible_item;
    Set!(TokenSymbol) look_ahead_set;
}

struct ReduceReduceConflict {
    GrammarItemKey[2] reducible_item;
    Set!(TokenSymbol) look_ahead_set_intersection;
}

bool trivially_true(Predicate predicate)
{
    return strip(predicate).length == 0 || predicate == "true";
}

string token_list_string(TokenSymbol[] tokens)
{
    if (tokens.length == 0) return "";
    string str = tokens[0].name;
    foreach (token; tokens[1..$]) {
        str ~= format(", %s", token.name);
    }
    return str;
}

alias uint ParserStateId;

class ParserState {
    mixin IdNumber!(ParserStateId);
    GrammarItemSet grammar_items;
    ParserState[TokenSymbol] shift_list;
    ParserState[NonTerminalSymbol] goto_table;
    ParserState error_recovery_state;
    ProcessedState state;
    ShiftReduceConflict[] shift_reduce_conflicts;
    ReduceReduceConflict[] reduce_reduce_conflicts;

    this(ParserStateId id, GrammarItemSet kernel)
    {
        this.id = id;
        grammar_items = kernel;
    }

    size_t resolve_shift_reduce_conflicts()
    {
        // Do this in two stages to obviate problems modifying shift_list
        ShiftReduceConflict[] conflicts;
        foreach(shift_symbol, goto_state; shift_list) {
            foreach (item, look_ahead_set; grammar_items) {
                if (item.is_reducible && look_ahead_set.contains(shift_symbol)) {
                    conflicts ~= ShiftReduceConflict(shift_symbol, goto_state, item, look_ahead_set);
                }
            }
        }
        shift_reduce_conflicts = [];
        foreach (conflict; conflicts) {
            with (conflict) {
                if (shift_symbol.precedence < reducible_item.production.precedence) {
                    shift_list.remove(shift_symbol);
                } else if (shift_symbol.precedence > reducible_item.production.precedence) {
                    grammar_items[reducible_item] -= shift_symbol;
                } else if (reducible_item.production.associativity == Associativity.left) {
                    shift_list.remove(shift_symbol);
                } else if (reducible_item.production.has_error_recovery_tail) {
                    grammar_items[reducible_item] -= shift_symbol;
                } else {
                    // Default: resolve in favour of shift but mark as
                    // unresolved giving the user the option of accepting
                    // the resolution or not (down the track)
                    grammar_items[reducible_item] -= shift_symbol;
                    shift_reduce_conflicts ~= conflict;
                }
            }
        }
        return shift_reduce_conflicts.length;
    }

    size_t resolve_reduce_reduce_conflicts()
    {
        reduce_reduce_conflicts = [];
        auto reducible_key_set = grammar_items.get_reducible_keys();
        if (reducible_key_set.cardinality < 2) return 0;

        auto keys = reducible_key_set.elements;
        for (auto i = 0; i < keys.length - 1; i++) {
            auto key1 = keys[i];
            foreach (key2; keys[i + 1..$]) {
                assert(key1.production.id < key2.production.id);
                auto intersection = (grammar_items[key1] & grammar_items[key2]);
                if (intersection.cardinality > 0 && trivially_true(key1.production.predicate)) {
                    if (key1.production.has_error_recovery_tail) {
                        grammar_items[key1] -= intersection;
                    } else if (key2.production.has_error_recovery_tail) {
                        grammar_items[key2] -= intersection;
                    } else {
                        // Default: resolve in favour of first declared
                        // production but mark as unresolved giving the
                        // user the option of accepting the resolution
                        // or not (down the track)
                        grammar_items[key2] -= intersection;
                        reduce_reduce_conflicts ~= ReduceReduceConflict([key1, key2], intersection);
                    }
                }
            }
        }
        return reduce_reduce_conflicts.length;
    }

    Set!TokenSymbol get_look_ahead_set()
    {
        auto look_ahead_set = extract_key_set(shift_list);
        foreach (key; grammar_items.get_reducible_keys()) {
            look_ahead_set |= grammar_items[key];
        }
        return look_ahead_set;
    }

    string[] generate_action_code_text()
    {
        string[] code_text_lines = ["switch (dd_next_token) {"];
        string expected_tokens_list;
        auto shift_token_set = extract_key_set(shift_list);
        foreach (token; shift_token_set) {
            code_text_lines ~= format("case %s: return dd_shift!(%s);", token.name, shift_list[token].id);
        }
        auto item_keys = grammar_items.get_reducible_keys();
        if (item_keys.cardinality == 0) {
            assert(shift_token_set.cardinality > 0);
            expected_tokens_list = token_list_string(shift_token_set.elements);
        } else {
            struct Pair { Set!TokenSymbol look_ahead_set; Set!GrammarItemKey production_set; };
            Pair[] pairs;
            auto combined_look_ahead = Set!TokenSymbol();
            foreach (item_key; item_keys) {
                combined_look_ahead |= grammar_items[item_key];
            }
            expected_tokens_list = token_list_string((shift_token_set | combined_look_ahead).elements);
            foreach (token; combined_look_ahead) {
                auto production_set = Set!GrammarItemKey();
                foreach (item_key; item_keys) {
                    if (grammar_items[item_key].contains(token)) {
                        production_set += item_key;
                    }
                }
                auto i = 0;
                for (i = 0; i < pairs.length; i++) {
                    if (pairs[i].production_set == production_set) break;
                }
                if (i < pairs.length) {
                    pairs[i].look_ahead_set += token;
                } else {
                    pairs ~= Pair(Set!TokenSymbol(token), production_set);
                }
            }
            foreach (pair; pairs) {
                code_text_lines ~= format("case %s:", token_list_string(pair.look_ahead_set.elements));
                auto keys = pair.production_set.elements;
                if (trivially_true(keys[0].production.predicate)) {
                    assert(keys.length == 1);
                    if (keys[0].production.id == 0) {
                        code_text_lines ~= "    return dd_accept!();";
                    } else {
                        code_text_lines ~= format("    return dd_reduce!(%s); // %s", keys[0].production.id, keys[0].production);
                    }
                } else {
                    code_text_lines ~= format("    if (%s) {", keys[0].production.expanded_predicate);
                    code_text_lines ~= format("        return dd_reduce!(%s); // %s", keys[0].production.id, keys[0].production);
                    if (keys.length == 1) {
                        code_text_lines ~= "    } else {";
                        code_text_lines ~= format("        throw new DDSyntaxError([%s]);", expected_tokens_list);
                        code_text_lines ~= "    }";
                        continue;
                    }
                    for (auto i = 1; i < keys.length - 1; i++) {
                        assert(!trivially_true(keys[i].production.predicate));
                        code_text_lines ~= format("    } else if (%s) {", keys[i].production.expanded_predicate);
                        code_text_lines ~= format("        return dd_reduce!(%s); // %s", keys[i].production.id, keys[i].production);
                    }
                    if (trivially_true(keys[$ - 1].production.predicate)) {
                        code_text_lines ~= "    } else {";
                        if (keys[$ - 1].production.id == 0) {
                            code_text_lines ~= "    return dd_accept;";
                        } else {
                            code_text_lines ~= format("        return dd_reduce!(%s); // %s", keys[$ - 1].production.id, keys[$ - 1].production);
                        }
                        code_text_lines ~= "    }";
                    } else {
                        code_text_lines ~= format("    } else if (%s) {", keys[$ - 1].production.expanded_predicate);
                        code_text_lines ~= format("        return dd_reduce!(%s); // %s", keys[$ - 1].production.id, keys[$ - 1].production);
                        code_text_lines ~= "    } else {";
                        code_text_lines ~= format("        throw new DDSyntaxError([%s]);", expected_tokens_list);
                        code_text_lines ~= "    }";
                    }
                }
            }
        }
        code_text_lines ~= "default:";
        code_text_lines ~= format("    throw new DDSyntaxError([%s]);", expected_tokens_list);
        code_text_lines ~= "}";
        return code_text_lines;
    }

    string[] generate_goto_code_text()
    {
        string[] code_text_lines = ["switch (dd_non_terminal) {"];
        foreach (symbol; goto_table.keys.sort) {
            code_text_lines ~= format("case %s: return %s;", symbol.name, goto_table[symbol].id);
        }
        code_text_lines ~= "default:";
        code_text_lines ~= format("    throw new Exception(format(\"Malformed goto table: no entry for (%%s , %s)\", dd_non_terminal));", id);
        code_text_lines ~= "}";
        return code_text_lines;
    }

    string get_description()
    {
        auto str = format("State<%s>:\n  Grammar Items:\n", id);
        foreach (item_key; grammar_items.keys.sort) {
            str ~= format("    %s: %s\n", item_key, grammar_items[item_key]);
        }
        auto look_ahead_set = get_look_ahead_set();
        str ~= format("  Parser Action Table:\n");
        if (look_ahead_set.cardinality== 0) {
            str ~= "    <empty>\n";
        } else {
            auto reducable_item_keys = grammar_items.get_reducible_keys();
            foreach (token; look_ahead_set) {
                if (token in shift_list) {
                    str ~= format("    %s: shift: -> State<%s>\n", token, shift_list[token].id);
                } else {
                    foreach (reducible_item_key; reducable_item_keys) {
                        if (grammar_items[reducible_item_key].contains(token)) {
                            str ~= format("    %s: reduce: %s\n", token, reducible_item_key.production);
                        }
                    }
                }
            }
        }
        str ~= "  Go To Table:\n";
        if (goto_table.length == 0) {
            str ~= "    <empty>\n";
        } else {
            foreach (non_terminal; goto_table.keys.sort) {
                str ~= format("    %s -> %s\n", non_terminal, goto_table[non_terminal]);
            }
        }
        if (error_recovery_state is null) {
            str ~= "  Error Recovery State: <none>\n";
        } else {
            str ~= format("  Error Recovery State: State<%s>\n", error_recovery_state.id);
            str ~= format("    Look Ahead: %s\n", error_recovery_state.get_look_ahead_set());
        }
        if (shift_reduce_conflicts.length > 0) {
            str ~= "  Shift/Reduce Conflicts:\n";
            foreach (src; shift_reduce_conflicts) {
                str ~= format("    %s:\n", src.shift_symbol);
                str ~= format("      shift -> State<%s>\n", src.goto_state.id);
                str ~= format("      reduce %s : %s\n", src.reducible_item.production, src.look_ahead_set);
            }
        }
        if (reduce_reduce_conflicts.length > 0) {
            str ~= "  Reduce/Reduce Conflicts:\n";
            foreach (rrc; reduce_reduce_conflicts) {
                str ~= format("    %s:\n", rrc.look_ahead_set_intersection);
                str ~= format("      reduce %s : %s\n", rrc.reducible_item[0].production, grammar_items[rrc.reducible_item[0]]);
                str ~= format("      reduce %s : %s\n", rrc.reducible_item[1].production, grammar_items[rrc.reducible_item[1]]);
            }
        }
        return str;
    }

    override string toString()
    {
        return format("State<%s>", id);
    }
}

class GrammarSpecification {
    SymbolTable symbol_table;
    Production[] production_list;
    string header_code_text;
    string preamble_code_text;
    string coda_code_text;

    invariant () {
        for (auto i = 0; i < production_list.length; i++) assert(production_list[i].id == i);
    }

    this()
    {
        symbol_table = SymbolTable();
        // Set the right hand side when start symbol is known.
        auto dummy_prod = new_production(symbol_table.get_special_symbol(SpecialSymbols.start), [], null, null);
        assert(dummy_prod.id == 0);
    }

    @property
    ProductionId next_production_id()
    {
        return cast(ProductionId) production_list.length;
    }

    Production new_production(NonTerminalSymbol lhs, Symbol[] rhs, Predicate pred, SemanticAction actn, AssociativePrecedence aprec=AssociativePrecedence())
    {
        auto new_prodn = new Production(next_production_id, lhs, rhs, pred, actn, aprec);
        production_list ~= new_prodn;
        if (new_prodn.id == 1) {
            production_list[0].right_hand_side = [new_prodn.left_hand_side];
            new_prodn.left_hand_side.used_at ~= new_prodn.left_hand_side.defined_at;
        }
        return new_prodn;
    }

    void set_header(string header)
    {
        header_code_text = header;
    }

    void set_preamble(string preamble)
    {
        preamble_code_text = preamble;
    }

    void set_coda(string coda)
    {
        coda_code_text = coda;
    }

    Set!TokenSymbol FIRST(Symbol[] symbol_string, TokenSymbol token)
    {
        auto token_set = Set!TokenSymbol();
        foreach (symbol; symbol_string) {
            auto firsts_data = get_firsts_data(symbol);
            token_set |= firsts_data.tokenset;
            if (!firsts_data.transparent) {
                return token_set;
            }
        }
        token_set += token;
        return token_set;
    }

    FirstsData get_firsts_data(ref Symbol symbol)
    {
        if (symbol.firsts_data is null ) {
            auto token_set = Set!TokenSymbol();
            auto transparent = false;
            if (symbol.type == SymbolType.token) {
                token_set += symbol;
            } else if (symbol.type == SymbolType.non_terminal) {
                // We need to establish transparency first
                Production[] relevant_productions;
                foreach (production; production_list) {
                    if (production.left_hand_side != symbol) continue;
                    transparent = transparent || (production.length == 0);
                    relevant_productions ~= production;
                }
                bool transparency_changed;
                do {
                    // TODO: modify this to only redo those before the change in transparency
                    transparency_changed = false;
                    foreach (production; relevant_productions) {
                        auto transparent_production = true;
                        foreach (rhs_symbol; production.right_hand_side) {
                            if (rhs_symbol == symbol) {
                                if (transparent) {
                                    continue;
                                } else {
                                    transparent_production = false;
                                    break;
                                }
                            }
                            auto firsts_data = get_firsts_data(rhs_symbol);
                            token_set |= firsts_data.tokenset;
                            if (!firsts_data.transparent) {
                                transparent_production = false;
                                break;
                            }
                        }
                        if (transparent_production) {
                            transparency_changed = !transparent;
                            transparent = true;
                        }
                    }
                } while (transparency_changed);
            }
            symbol.firsts_data = new FirstsData(token_set, transparent);
        }
        return symbol.firsts_data;
    }

    GrammarItemSet closure(GrammarItemSet closure_set)
    {
        // NB: if called with an lValue arg that lValue will also be modified
        bool additions_made;
        do {
            additions_made = false;
            foreach (item_key, look_ahead_set; closure_set) {
                if (!item_key.is_closable) continue;
                auto prospective_lhs = item_key.next_symbol;
                foreach (look_ahead_symbol; look_ahead_set) {
                    auto firsts = FIRST(item_key.tail, look_ahead_symbol);
                    foreach (production; production_list) {
                        if (prospective_lhs != production.left_hand_side) continue;
                        auto prospective_key = GrammarItemKey(production);
                        if (prospective_key in closure_set) {
                            auto cardinality = closure_set[prospective_key].cardinality;
                            closure_set[prospective_key] |= firsts;
                            additions_made = additions_made || closure_set[prospective_key].cardinality > cardinality;
                        } else {
                            // NB: need clone to ensure each GrammarItems don't share look ahead sets
                            closure_set[prospective_key] = firsts.clone();
                            additions_made = true;
                        }
                    }
                }
            }
        } while (additions_made);
        return closure_set;
    }

    string[] get_description()
    {
        auto text_lines = symbol_table.get_description();
        text_lines ~= "Productions:";
        foreach (pdn; production_list) {
            text_lines ~= format("  %s: %s: %s: %s", pdn.id, pdn, pdn.associativity, pdn.precedence);
        }
        return text_lines;
    }
}

string quote_raw(string str)
{
    static auto re = regex(r"`", "g");
    return "`" ~ replace(str, re, "`\"`\"`") ~ "`";
}

class Grammar {
    GrammarSpecification spec;
    ParserState[] parser_states;
    Set!(ParserState)[ParserState][NonTerminalSymbol] goto_table;
    ParserStateId[] empty_look_ahead_sets;
    size_t unresolved_sr_conflicts;
    size_t unresolved_rr_conflicts;

    invariant () {
        for (auto i = 0; i < parser_states.length; i++) assert(parser_states[i].id == i);
    }

    @property
    size_t total_unresolved_conflicts()
    {
        return unresolved_rr_conflicts + unresolved_sr_conflicts;
    }

    @property
    ParserStateId next_parser_state_id()
    {
        return cast(ParserStateId) parser_states.length;
    }

    ParserState new_parser_state(GrammarItemSet kernel)
    {
        auto nps = new ParserState(next_parser_state_id, kernel);
        parser_states ~= nps;
        return nps;
    }

    this(GrammarSpecification specification)
    {
        spec = specification;
        auto start_item_key = GrammarItemKey(spec.production_list[0]);
        auto start_look_ahead_set = Set!(TokenSymbol)(spec.symbol_table.get_special_symbol(SpecialSymbols.end));
        GrammarItemSet start_kernel = spec.closure([ start_item_key : start_look_ahead_set]);
        auto start_state = new_parser_state(start_kernel);
        while (true) {
            // Find a state that needs processing or quit
            ParserState unprocessed_state = null;
            // Go through states in id order
            foreach (parser_state; parser_states) {
                if (parser_state.state != ProcessedState.processed) {
                    unprocessed_state = parser_state;
                    break;
                }
            }
            if (unprocessed_state is null) break;

            auto first_time = unprocessed_state.state == ProcessedState.unprocessed;
            unprocessed_state.state = ProcessedState.processed;
            auto already_done = Set!Symbol();
            // do items in order
            foreach (item_key; unprocessed_state.grammar_items.keys.sort){
                if (item_key.is_reducible) continue;
                ParserState goto_state;
                auto symbol_x = item_key.next_symbol;
                if (already_done.contains(symbol_x)) continue;
                already_done += symbol_x;
                auto item_set_x = spec.closure(unprocessed_state.grammar_items.generate_goto_kernel(symbol_x));
                auto equivalent_state = find_equivalent_state(item_set_x);
                if (equivalent_state is null) {
                    goto_state = new_parser_state(item_set_x);
                } else {
                    foreach (item_key, look_ahead_set; item_set_x) {
                        if (!equivalent_state.grammar_items[item_key].is_superset_of(look_ahead_set)) {
                            equivalent_state.grammar_items[item_key] |= look_ahead_set;
                            if (equivalent_state.state == ProcessedState.processed) {
                                equivalent_state.state = ProcessedState.needs_reprocessing;
                            }
                        }
                    }
                    goto_state = equivalent_state;
                }
                if (first_time) {
                    if (symbol_x.type == SymbolType.token) {
                        unprocessed_state.shift_list[symbol_x] = goto_state;
                    } else {
                        assert(symbol_x !in unprocessed_state.goto_table);
                        unprocessed_state.goto_table[symbol_x] = goto_state;
                    }
                    if (symbol_x.id == SpecialSymbols.parse_error) {
                        unprocessed_state.error_recovery_state = goto_state;
                    }
                }
            }

        }
        foreach (parser_state; parser_states) {
            if (parser_state.get_look_ahead_set().cardinality == 0) {
                empty_look_ahead_sets ~= parser_state.id;
            }
            unresolved_sr_conflicts += parser_state.resolve_shift_reduce_conflicts();
            unresolved_rr_conflicts += parser_state.resolve_reduce_reduce_conflicts();
        }
    }

    ParserState find_equivalent_state(GrammarItemSet grammar_item_set)
    {
        // TODO: check if this needs to use only kernel keys
        auto target_key_set = grammar_item_set.get_kernel_keys();
        foreach (parser_state; parser_states) {
            if (target_key_set == parser_state.grammar_items.get_kernel_keys()) {
                return parser_state;
            }
        }
        return null;
    }

    string[] generate_symbol_enum_code_text()
    {
        // TODO: determine type for DDSymbol from maximum symbol id
        string[] text_lines = ["alias ushort DDSymbol;\n"];
        text_lines ~= "enum DDHandle : DDSymbol {";
        foreach (token; spec.symbol_table.get_special_tokens_ordered()) {
            text_lines ~= format("    %s = %s,", token.name, token.id);
        }
        auto ordered_tokens = spec.symbol_table.get_tokens_ordered();
        foreach (token; ordered_tokens) {
            text_lines ~= format("    %s = %s,", token.name, token.id);
        }
        text_lines ~= "}\n";
        text_lines ~= "string dd_literal_token_string(DDHandle dd_token)";
        text_lines ~= "{";
        text_lines ~= "    with (DDHandle) switch (dd_token) {";
        foreach (token; ordered_tokens) {
            if (token.pattern[0] == '"') {
                text_lines ~= format("    case %s: return %s; break;", token.name, token.pattern);
            }
        }
        text_lines ~= "    default:";
        text_lines ~= "    }";
        text_lines ~= "    return null;";
        text_lines ~= "}\n";
        text_lines ~= "enum DDNonTerminal : DDSymbol {";
        foreach (non_terminal; spec.symbol_table.get_special_non_terminals_ordered()) {
            text_lines ~= format("    %s = %s,", non_terminal.name, non_terminal.id);
        }
        foreach (non_terminal; spec.symbol_table.get_non_terminals_ordered()) {
            text_lines ~= format("    %s = %s,", non_terminal.name, non_terminal.id);
        }
        text_lines ~= "}\n";
        return text_lines;
    }

    string[] generate_lexan_token_code_text()
    {
        string[] text_lines = ["static DDLexicalAnalyser dd_lexical_analyser;"];
        text_lines ~= "static this() {";
        text_lines ~= "    static auto dd_lit_lexemes = [";
        foreach (token; spec.symbol_table.get_tokens_ordered()) {
            if (!(token.pattern[0] == '"' && token.pattern[$-1] == '"')) continue;
            text_lines ~= format("        DDLiteralLexeme(DDHandle.%s, %s),", token.name, token.pattern);
        }
        text_lines ~= "    ];\n";
        text_lines ~= "    static auto dd_regex_lexemes = [";
        foreach (token; spec.symbol_table.get_tokens_ordered()) {
            if ((token.pattern[0] == '"' && token.pattern[$-1] == '"')) continue;
            text_lines ~= format("        DDRegexLexeme!(DDHandle.%s, %s),", token.name, quote_raw(token.pattern));
        }
        text_lines ~= "    ];\n";
        text_lines ~= "    static auto dd_skip_rules = [";
        foreach (rule; spec.symbol_table.get_skip_rules()) {
            text_lines ~= format("        regex(%s),", quote_raw("^" ~ rule));
        }
        text_lines ~= "    ];\n";
        text_lines ~= "    dd_lexical_analyser = new DDLexicalAnalyser(dd_lit_lexemes, dd_regex_lexemes, dd_skip_rules);";
        text_lines ~= "}\n";
        return text_lines;
    }

    string[] generate_attributes_code_text()
    {
        string[] text_lines = ["struct DDAttributes {"];
        text_lines ~= "    DDCharLocation dd_location;";
        text_lines ~= "    string dd_matched_text;";
        auto fields = spec.symbol_table.get_field_definitions();
        if (fields.length > 0) {
            text_lines ~= "    union {";
            text_lines ~= "        DDSyntaxErrorData dd_syntax_error_data;";
            foreach (field; fields) {
                text_lines ~= format("        %s %s;", field.field_type, field.field_name);
            }
            text_lines ~= "    }\n";
        } else {
            text_lines ~= "    DDSyntaxErrorData dd_syntax_error_data;\n";
        }
        text_lines ~= "    this (DDToken token)";
        text_lines ~= "    {";
        text_lines ~= "        dd_location = token.location;";
        text_lines ~= "        dd_matched_text = token.matched_text;";
        text_lines ~= "        if (token.is_valid_match) {";
        text_lines ~= "            dd_set_attribute_value(this, token.handle, token.matched_text);";
        text_lines ~= "        }";
        text_lines ~= "    }";
        text_lines ~= "}\n\n";
        text_lines ~= "void dd_set_attribute_value(ref DDAttributes attrs, DDHandle dd_token, string text)";
        text_lines ~= "{";
        Set!TokenSymbol[string] token_sets;
        foreach(token; spec.symbol_table.get_tokens_ordered()) {
            if (token.field_name.length > 0) {
                if (token.field_name !in token_sets) {
                    token_sets[token.field_name] = Set!TokenSymbol(token);
                } else {
                    token_sets[token.field_name] += token;
                }
            }
        }
        if (token_sets.length > 0) {
            text_lines ~= "    with (DDHandle) switch (dd_token) {";
            foreach (field; fields) {
                if (field.field_name in token_sets) {
                    text_lines ~= format("    case %s:", token_list_string(token_sets[field.field_name].elements));
                    if (field.conversion_function_name.length > 0) {
                        text_lines ~= format("        attrs.%s  = %s(text);", field.field_name, field.conversion_function_name);
                    } else {
                        text_lines ~= format("        attrs.%s  = to!(%s)(text);", field.field_name, field.field_type);
                    }
                    text_lines ~= "        break;";
                }
            }
            text_lines ~= "    default:";
            text_lines ~= "        // Do nothing";
            text_lines ~= "    }";
        }
        text_lines ~= "}\n";
        return text_lines;
    }

    string[] generate_production_data_code_text()
    {
        string[] text_lines = ["alias uint DDProduction;"];
        text_lines ~= "DDProductionData dd_get_production_data(DDProduction dd_production)";
        text_lines ~= "{";
        text_lines ~= "    with (DDNonTerminal) switch(dd_production) {";
        foreach (production; spec.production_list) {
            text_lines ~= format("    case %s: return DDProductionData(%s, %s);", production.id, production.left_hand_side.name, production.right_hand_side.length);
        }
        text_lines ~= "    default:";
        text_lines ~= "        throw new Exception(\"Malformed production data table\");";
        text_lines ~= "    }";
        text_lines ~= "    assert(false);";
        text_lines ~= "}\n";
        return text_lines;
    }

    string[] generate_semantic_code_text()
    {
        string[] text_lines = ["void"];
        text_lines ~= "dd_do_semantic_action(ref DDAttributes dd_lhs, DDProduction dd_production, DDAttributes[] dd_args, void delegate(string, string) dd_inject)";
        text_lines ~= "{";
        text_lines ~= "    switch(dd_production) {";
        foreach (production; spec.production_list) {
            if (production.action.length > 0) {
                text_lines ~= format("    case %s: // %s", production.id, production);
                text_lines ~= production.expanded_semantic_action;
                text_lines ~= "        break;";
            }
        }
        text_lines ~= "    default:";
        text_lines ~= "        // Do nothing";
        text_lines ~= "    }";
        text_lines ~= "}\n";
        return text_lines;
    }

    string[] generate_action_table_code_text()
    {
        string[] code_text_lines = [];
        code_text_lines ~= "DDParseAction dd_get_next_action(DDParserState dd_current_state, DDHandle dd_next_token, in DDAttributes[] dd_attribute_stack)";
        code_text_lines ~= "{";
        code_text_lines ~= "    with (DDHandle) switch(dd_current_state) {";
        // Do this in state id order
        auto indent = "        ";
        foreach (parser_state; parser_states) {
            code_text_lines ~= format("    case %s:", parser_state.id);
            foreach (line; parser_state.generate_action_code_text()) {
                auto indented_line = indent ~ line;
                code_text_lines ~= indented_line;
            }
            code_text_lines ~= "        break;";
        }
        code_text_lines ~= "    default:";
        code_text_lines ~= "        throw new Exception(format(\"Invalid parser state: %s\", dd_current_state));";
        code_text_lines ~= "    }";
        code_text_lines ~= "    assert(false);";
        code_text_lines ~= "}\n";
        return code_text_lines;
    }

    string[] generate_goto_table_code_text()
    {
        string[] code_text_lines = ["alias uint DDParserState;"];
        code_text_lines ~= "DDParserState dd_get_goto_state(DDNonTerminal dd_non_terminal, DDParserState dd_current_state)";
        code_text_lines ~= "{";
        code_text_lines ~= "    with (DDNonTerminal) switch(dd_current_state) {";
        // Do this in state id order
        auto indent = "        ";
        foreach (parser_state; parser_states) {
            if (parser_state.goto_table.length == 0) continue;
            code_text_lines ~= format("    case %s:", parser_state.id);
            foreach (line; parser_state.generate_goto_code_text()) {
                auto indented_line = indent ~ line;
                code_text_lines ~= indented_line;
            }
            code_text_lines ~= "        break;";
        }
        code_text_lines ~= "    default:";
        code_text_lines ~= "        throw new Exception(format(\"Malformed goto table: no entry for (%s, %s).\", dd_non_terminal, dd_current_state));";
        code_text_lines ~= "    }";
        code_text_lines ~= "    throw new Exception(format(\"Malformed goto table: no entry for (%s, %s).\", dd_non_terminal, dd_current_state));";
        code_text_lines ~= "}\n";
        return code_text_lines;
    }

    string[] generate_error_recovery_code_text()
    {
        string[] code_text_lines = ["bool dd_error_recovery_ok(DDParserState dd_parser_state, DDHandle dd_token)"];
        code_text_lines ~= "{";
        code_text_lines ~= "    with (DDHandle) switch(dd_parser_state) {";
        // Do this in state id order
        foreach (parser_state; parser_states) {
            if (parser_state.error_recovery_state is null) continue;
            auto error_recovery_set = Set!TokenSymbol();
            foreach (item_key, look_ahead_set; parser_state.error_recovery_state.grammar_items) {
                if (item_key.dot > 0 && item_key.production.right_hand_side[item_key.dot - 1].id == SpecialSymbols.parse_error) {
                    error_recovery_set |= look_ahead_set;
                }
            }
            if (error_recovery_set.cardinality > 0) {
                code_text_lines ~= format("    case %s:", parser_state.id);
                code_text_lines ~= "        switch (dd_token) {";
                code_text_lines ~= format("        case %s:", token_list_string(error_recovery_set.elements));
                code_text_lines ~= "            return true;";
                code_text_lines ~= "        default:";
                code_text_lines ~= "            return false;";
                code_text_lines ~= "        }";
                code_text_lines ~= "        break;";
            }
        }
        code_text_lines ~= "    default:";
        code_text_lines ~= "    }";
        code_text_lines ~= "    return false;";
        code_text_lines ~= "}\n";
        return code_text_lines;
    }

    void write_parser_code(File output_file, string module_name="")
    in {
        assert(output_file.isOpen);
        assert(output_file.size == 0);
    }
    body {
        if (module_name.length > 0) {
            output_file.writefln("module %s;\n", module_name);
        }
        output_file.writeln(stripLeft(spec.header_code_text));
        output_file.writeln("import ddlib.templates;\n");
        output_file.writeln("mixin DDParserSupport;\n");
        foreach (line; generate_symbol_enum_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_lexan_token_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_production_data_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_attributes_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_goto_table_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_error_recovery_code_text()) {
            output_file.writeln(line);
        }
        output_file.writeln(spec.preamble_code_text);
        foreach (line; generate_semantic_code_text()) {
            output_file.writeln(line);
        }
        foreach (line; generate_action_table_code_text()) {
            output_file.writeln(line);
        }
        output_file.writeln("\nmixin DDImplementParser;");
        output_file.writeln(spec.coda_code_text.stripRight);
        output_file.close();
    }

    string get_parser_states_description()
    {
        string str;
        foreach (parser_state; parser_states) {
            str ~= parser_state.get_description();
        }
        return str;
    }
}
