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

import ddlib.components;
import symbols;
import sets;
import idnumber;

alias string Predicate;
alias string SemanticAction;

class Production {
    mixin UniqueId!(ProductionId);
    NonTerminalSymbol leftHandSide;
    Symbol[] rightHandSide;
    Associativity associativity;
    Precedence    precedence;
    Predicate predicate;
    SemanticAction action;

    this()
    {
        mixin(set_unique_id);
    }

    this(NonTerminalSymbol lhs, Symbol[] rhs)
    {
        this();
        leftHandSide = lhs;
        rightHandSide = rhs;
    }

    this(NonTerminalSymbol lhs, Symbol[] rhs, SemanticAction action)
    {
        this(lhs, rhs);
        this.action = action;
    }

    @property
    const size_t length()
    {
        return rightHandSide.length;
    }

    @property
    string expanded_predicate()
    {
        static auto stackAttr_re = regex(r"\$(\d+)", "g");
        auto replaceWith = format("ddAttributeStack[$$ - %s + $1]", rightHandSide.length + 1);
        return replace(predicate, stackAttr_re, replaceWith);
    }

    @property
    string expanded_semantic_action()
    {
        static auto lhs_re = regex(r"\$\$", "g");
        static auto stackAttr_re = regex(r"\$(\d+)", "g");
        return replace(replace(action, lhs_re, "ddLhs"), stackAttr_re, "ddArgs[$1 - 1]");
    }

    override string toString()
    {
        // This is just for use in generated code comments
        if (rightHandSide.length == 0) {
            return format("%s: <empty>", leftHandSide.name);
        }
        auto str = format("%s:", leftHandSide.name);
        foreach (symbol; rightHandSide) {
            str ~= format(" %s", symbol);
        }
        if (predicate.length > 0) {
            str ~= format(" ?( %s ?)", predicate);
        }
        return str;
    }
}

class GrammarItemKey {
    Production production;
    uint dot;
    invariant () {
        assert(dot <= production.length);
    }

    this(Production production)
    {
        this.production = production;
    }

    GrammarItemKey
    clone_shifted()
    {
        if (dot > production.length) {
            return null;
        }
        auto cloned = new GrammarItemKey(production);
        cloned.dot = dot + 1;
        return cloned;
    }

    @property
    bool is_shiftable()
    {
        return dot < production.length;
    }

    @property
    bool is_kernel_item()
    {
        return dot > 0 || production.leftHandSide.id == SpecialSymbols.start;
    }

    @property
    Symbol nextSymbol()
    in {
        assert(is_shiftable);
    }
    body {
        return production.rightHandSide[dot];
    }

    @property
    Symbol[] tail()
    in {
        assert(is_shiftable);
    }
    body {
        return production.rightHandSide[dot + 1 .. $];
    }

    bool next_symbol_is(Symbol symbol)
    {
        return is_shiftable && nextSymbol == symbol;
    }

    override hash_t toHash()
    {
        return production.id * (dot + 1);
    }

    override bool opEquals(Object o)
    {
        GrammarItemKey other = cast(GrammarItemKey) o;
        return production.id == other.production.id && dot == other.dot;
    }

    override int opCmp(Object o)
    {
        GrammarItemKey other = cast(GrammarItemKey) o;
        if (production.id == other.production.id) {
            return dot - other.dot;
        }
        return production.id - other.production.id;
    }

    override string toString()
    {
        with (production) {
            // This is just for use in debugging
            if (rightHandSide.length == 0) {
                return format("%s: . <empty>", leftHandSide.name);
            }
            auto str = format("%s:", leftHandSide.name);
            for (auto i = 0; i < rightHandSide.length; i++) {
                if (i == dot) {
                    str ~= " .";
                }
                str ~= format(" %s", rightHandSide[i]);
            }
            if (dot == rightHandSide.length) {
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
    auto keySet = new Set!GrammarItemKey;
    foreach (grammarItemKey; itemset.byKey()) {
        if (grammarItemKey.is_kernel_item) {
            keySet.add(grammarItemKey);
        }
    }
    return keySet;
}

Set!GrammarItemKey get_closable_keys(GrammarItemSet itemset)
{
    auto keySet = new Set!GrammarItemKey;
    foreach (grammarItemKey; itemset.byKey()) {
        if (grammarItemKey.is_shiftable && grammarItemKey.nextSymbol.type == SymbolType.nonTerminal) {
            keySet.add(grammarItemKey);
        }
    }
    return keySet;
}

Set!GrammarItemKey get_reducible_keys(GrammarItemSet itemset)
{
    auto keySet = new Set!GrammarItemKey;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (!grammarItemKey.is_shiftable) {
            keySet.add(grammarItemKey);
        }
    }
    return keySet;
}

GrammarItemSet generate_goto_kernel(GrammarItemSet itemset, Symbol symbol)
{
    GrammarItemSet goto_kernel;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (grammarItemKey.next_symbol_is(symbol)) {
            goto_kernel[grammarItemKey.clone_shifted()] = lookAheadSet.clone();
        }
    }
    return goto_kernel;
}

enum ProcessedState { unProcessed, needsReprocessing, processed };

struct ShiftReduceConflict {
    TokenSymbol shiftSymbol;
    ParserState gotoState;
    GrammarItemKey reducibleItem;
    Set!(TokenSymbol) lookAheadSet;
}

struct ReduceReduceConflict {
    GrammarItemKey[2] reducibleItem;
    Set!(TokenSymbol) lookAheadSetIntersection;
}

bool trivially_true(Predicate predicate)
{
    return strip(predicate).length == 0 || predicate == "true";
}

string token_list_string(TokenSymbol[] tokens)
{
    if (tokens.length == 0) return "";
    auto str = tokens[0].name;
    foreach (token; tokens[1 .. $]) {
        str ~= format(", %s", token.name);
    }
    return str;
}

class ParserState {
    mixin UniqueId!(ParserStateId);
    GrammarItemSet grammarItems;
    ParserState[TokenSymbol] shiftList;
    ParserState[NonTerminalSymbol] gotoTable;
    ParserState errorRecoveryState;
    ProcessedState state;
    ShiftReduceConflict[] shiftReduceConflicts;
    ReduceReduceConflict[] reduceReduceConflicts;

    this(GrammarItemSet kernel)
    {
        mixin(set_unique_id);
        grammarItems = kernel;
    }

    size_t resolve_shift_reduce_conflicts()
    {
        // Do this in two stages to obviate problems modifying shiftList
        ShiftReduceConflict[] conflicts;
        foreach(shiftSymbol, gotoState; shiftList) {
            foreach (item, lookAheadSet; grammarItems) {
                if (!item.is_shiftable && lookAheadSet.contains(shiftSymbol)) {
                    conflicts ~= ShiftReduceConflict(shiftSymbol, gotoState, item, lookAheadSet);
                }
            }
        }
        shiftReduceConflicts = [];
        foreach (conflict; conflicts) {
            with (conflict) {
                if (reducibleItem.production.length == 0) {
                    grammarItems[reducibleItem].remove(shiftSymbol);
                } else if (shiftSymbol.precedence < reducibleItem.production.precedence) {
                    shiftList.remove(shiftSymbol);
                } else if (shiftSymbol.precedence > reducibleItem.production.precedence) {
                    grammarItems[reducibleItem].remove(shiftSymbol);
                } else if (shiftSymbol.associativity == Associativity.left) {
                    shiftList.remove(shiftSymbol);
                } else if (shiftSymbol.associativity == Associativity.right) {
                    grammarItems[reducibleItem].remove(shiftSymbol);
                } else if (reducibleItem.production.length && reducibleItem.production.rightHandSide[$ - 1].id == SpecialSymbols.parseError) {
                    grammarItems[reducibleItem].remove(shiftSymbol);
                } else {
                    shiftReduceConflicts ~= conflict;
                }
            }
        }
        return shiftReduceConflicts.length;
    }

    size_t resolve_reduce_reduce_conflicts()
    {
        reduceReduceConflicts = [];
        auto reducibleKeySet = get_reducible_keys(grammarItems);
        if (reducibleKeySet.cardinality < 2) return 0;
        
        auto keys = reducibleKeySet.elements;
        for (auto i = 0; i < keys.length - 1; i++) {
            auto key1 = keys[i];
            foreach (key2; keys[i + 1 .. $]) {
                auto intersection = set_intersection(grammarItems[key1], grammarItems[key2]);
                if (intersection.cardinality > 0) {
                    if (key1.production.precedence < key2.production.precedence) {
                        grammarItems[key1].remove(intersection);
                    } else if (key1.production.precedence > key2.production.precedence) {
                        grammarItems[key2].remove(intersection);
                    } else if (key1.production.id < key2.production.id && !trivially_true(key1.production.predicate)) {
                        // do nothing: resolved at runtime by evaluating predicate
                    } else if (key2.production.id < key1.production.id && !trivially_true(key2.production.predicate)) {
                        // do nothing: resolved at runtime by evaluating predicate
                    } else if (key1.production.length && key1.production.rightHandSide[$ - 1].id == SpecialSymbols.parseError) {
                        grammarItems[key1].remove(intersection);
                    } else if (key2.production.length && key2.production.rightHandSide[$ - 1].id == SpecialSymbols.parseError) {
                        grammarItems[key2].remove(intersection);
                    } else {
                        reduceReduceConflicts ~= ReduceReduceConflict([key1, key2], intersection);
                    }
                }
            }
        }
        return reduceReduceConflicts.length;
    }

    Set!TokenSymbol get_look_ahead_set()
    {
        auto lookAheadSet = extract_key_set(shiftList);
        foreach (key; get_reducible_keys(grammarItems).elements) {
            lookAheadSet.add(grammarItems[key]);
        }
        return lookAheadSet;
    }

    string[] generate_action_code_text()
    {
        string[] codeTextLines = ["switch (ddToken) {"];
        string expectedTokensList;
        auto shiftTokenSet = extract_key_set(shiftList);
        foreach (token; shiftTokenSet.elements) {
            codeTextLines ~= format("case %s: return ddShift(%s);", token.name, shiftList[token].id);
        }
        auto itemKeys = get_reducible_keys(grammarItems);
        if (itemKeys.cardinality == 0) {
            assert(shiftTokenSet.cardinality > 0);
            expectedTokensList = token_list_string(shiftTokenSet.elements);
        } else {
            struct Pair { Set!TokenSymbol lookAheadSet; Set!GrammarItemKey productionSet; };
            Pair[] pairs;
            auto combinedLookAhead = new Set!TokenSymbol;
            foreach (itemKey; itemKeys.elements) {
                combinedLookAhead.add(grammarItems[itemKey]);
            }
            expectedTokensList = token_list_string(set_union(shiftTokenSet, combinedLookAhead).elements);
            foreach (token; combinedLookAhead.elements) {
                auto productionSet = new Set!GrammarItemKey;
                foreach (itemKey; itemKeys.elements) {
                    if (grammarItems[itemKey].contains(token)) {
                        productionSet.add(itemKey);
                    }
                }
                auto i = 0;
                for (i = 0; i < pairs.length; i++) {
                    if (pairs[i].productionSet == productionSet) break;
                }
                if (i < pairs.length) {
                    pairs[i].lookAheadSet.add(token);
                } else {
                    pairs ~= Pair(new Set!TokenSymbol(token), productionSet);
                }
            }
            foreach (pair; pairs) {
                codeTextLines ~= format("case %s:", token_list_string(pair.lookAheadSet.elements));
                auto keys = pair.productionSet.elements;
                if (trivially_true(keys[0].production.predicate)) {
                    assert(keys.length == 1);
                    if (keys[0].production.id == 0) {
                        codeTextLines ~= "    return ddAccept;";
                    } else {
                        codeTextLines ~= format("    return ddReduce(%s); // %s", keys[0].production.id, keys[0].production);
                    }
                } else {
                    codeTextLines ~= format("    if (%s) {", keys[0].production.expanded_predicate);
                    codeTextLines ~= format("        return ddReduce(%s); // %s", keys[0].production.id, keys[0].production);
                    if (keys.length == 1) {
                        codeTextLines ~= "    } else {";
                        codeTextLines ~= format("        return ddError([%s]);", expectedTokensList);
                        codeTextLines ~= "    }";
                        continue;
                    }
                    for (auto i = 1; i < keys.length - 1; i++) {
                        assert(!trivially_true(keys[i].production.predicate));
                        codeTextLines ~= format("    } else if (%s) {", keys[i].production.expanded_predicate);
                        codeTextLines ~= format("        return ddReduce(%s); // %s", keys[i].production.id, keys[i].production);
                    }
                    if (trivially_true(keys[$ - 1].production.predicate)) {
                        codeTextLines ~= "    } else {";
                        if (keys[$ - 1].production.id == 0) {
                            codeTextLines ~= "    return ddAccept;";
                        } else {
                            codeTextLines ~= format("        return ddReduce(%s); // %s", keys[$ - 1].production.id, keys[$ - 1].production);
                        }
                        codeTextLines ~= "    }";
                    } else {
                        codeTextLines ~= format("    } else if (%s) {", keys[$ - 1].production.expanded_predicate);
                        codeTextLines ~= format("        return ddReduce(%s); // %s", keys[$ - 1].production.id, keys[$ - 1].production);
                        codeTextLines ~= "    } else {";
                        codeTextLines ~= format("        return ddError([%s]);", expectedTokensList);
                        codeTextLines ~= "    }";
                    }
                }
            }
        }
        codeTextLines ~= "default:";
        codeTextLines ~= format("    return ddError([%s]);", expectedTokensList);
        codeTextLines ~= "}";
        return codeTextLines;
    }

    string[] generate_goto_code_text()
    {
        string[] codeTextLines = ["switch (ddNonTerminal) {"];
        auto gotoSymbolSet = extract_key_set(gotoTable);
        foreach (symbol; gotoSymbolSet.elements) {
            codeTextLines ~= format("case %s: return %s;", symbol.name, gotoTable[symbol].id);
        }
        codeTextLines ~= "default:";
        codeTextLines ~= format("    throw new Exception(format(\"Malformed goto table: no entry for (%%s , %s)\", ddNonTerminal));", id);
        codeTextLines ~= "}";
        return codeTextLines;
    }

    string get_description()
    {
        auto str = format("State<%s>:\n  Grammar Items:\n", id);
        foreach (itemKey; extract_key_set(grammarItems).elements) {
            str ~= format("    %s: %s\n", itemKey, grammarItems[itemKey]);
        }
        auto lookAheadSet = get_look_ahead_set();
        str ~= format("  Parser Action Table:\n");
        if (lookAheadSet.cardinality== 0) {
            str ~= "    <empty>\n";
        } else {
            auto reducableItemkeys = get_reducible_keys(grammarItems);
            foreach (token; lookAheadSet.elements) {
                if (token in shiftList) {
                    str ~= format("    %s: shift: -> State<%s>\n", token, shiftList[token].id);
                } else {
                    foreach (reducibleItemKey; reducableItemkeys.elements) {
                        if (grammarItems[reducibleItemKey].contains(token)) {
                            str ~= format("    %s: reduce: %s\n", token, reducibleItemKey.production);
                        }
                    }
                }
            }
        }
        str ~= "  Go To Table:\n";
        if (gotoTable.length == 0) {
            str ~= "    <empty>\n";
        } else {
            foreach (nonTerminal; extract_key_set(gotoTable).elements) {
                str ~= format("    %s -> %s\n", nonTerminal, gotoTable[nonTerminal]);
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
    SymbolTable symbolTable;
    Production[ProductionId] productionList;
    string preambleCodeText;

    this()
    {
        this(new SymbolTable);
    }

    this(SymbolTable symbolTable)
    {
        auto dummyProd = new Production;
        assert(dummyProd.id == 0);
        dummyProd.leftHandSide = symbolTable.get_symbol(SpecialSymbols.start);
        // Set the right hand side when start symbol is known.
        productionList[dummyProd.id] = dummyProd;
        this.symbolTable = symbolTable;
    }

    void set_preamble(string preamble)
    {
        preambleCodeText = preamble;
    }

    void add_production(Production newProdn)
    {
        if (newProdn.id == 1) {
            productionList[0].rightHandSide = [newProdn.leftHandSide];
        }
        productionList[newProdn.id] = newProdn;
    }

    Set!TokenSymbol FIRST(Symbol[] symbolString, TokenSymbol token)
    {
        auto tokenSet = new Set!TokenSymbol;
        foreach (symbol; symbolString) {
            auto firstsData = get_firsts_data(symbol);
            tokenSet.add(firstsData.tokenset);
            if (!firstsData.transparent) {
                return tokenSet;
            }
        }
        tokenSet.add(token);
        return tokenSet;
    }

    FirstsData get_firsts_data(Symbol symbol)
    {
        if (symbol.firstsData is null ) {
            auto tokenSet = new Set!TokenSymbol;
            auto transparent = false;
            if (symbol.type == SymbolType.token) {
                tokenSet.add(symbol);
            } else if (symbol.type == SymbolType.nonTerminal) {
                // We need to establish transparency first
                Production[] relevantProductions;
                foreach (production; productionList) {
                    if (production.leftHandSide != symbol) continue;
                    transparent = transparent || (production.length == 0);
                    relevantProductions ~= production;
                }
                foreach (production; relevantProductions) {
                    foreach (rhsSymbol; production.rightHandSide) {
                        if (rhsSymbol == symbol) {
                            if (transparent) {
                                continue;
                            } else {
                                break;
                            }
                        }
                        auto firstsData = get_firsts_data(rhsSymbol);
                        tokenSet.add(firstsData.tokenset);
                        if (!firstsData.transparent) {
                            break;
                        }
                    }
                }
            }
            symbol.firstsData = new FirstsData(tokenSet, transparent);
        }
        return symbol.firstsData;
    }

    GrammarItemSet closure(GrammarItemSet itemSet)
    {
        auto closureSet = itemSet.dup;
        bool additions_made;
        do {
            additions_made = false;
            auto closableItemKeys = get_closable_keys(closureSet);
            foreach (closableItemKey; closableItemKeys.elements) {
                auto prospectiveLhs = closableItemKey.nextSymbol;
                auto lookAheadSet = closureSet[closableItemKey];
                foreach (lookAheadSymbol; lookAheadSet.elements) {
                    auto firsts = FIRST(closableItemKey.tail, lookAheadSymbol);
                    foreach (production; productionList) {
                        if (prospectiveLhs != production.leftHandSide) continue;
                        auto prospectiveKey = new GrammarItemKey(production);
                        if (prospectiveKey in closureSet) {
                            auto cardinality = closureSet[prospectiveKey].cardinality;
                            closureSet[prospectiveKey].add(firsts);
                            additions_made = additions_made || closureSet[prospectiveKey].cardinality > cardinality;
                        } else {
                            closureSet[prospectiveKey] = firsts.clone();
                            additions_made = true;
                        }
                    }
                }
            }
        } while (additions_made);
        return closureSet;
    }

    string[] get_description()
    {
        auto textLines = symbolTable.get_description();
        textLines ~= "Productions:";
        for (auto i = 0; i < productionList.length; i++) {
            auto pdn = productionList[i];
            textLines ~= format("  %s: %s: %s: %s", i, pdn, pdn.associativity, pdn.precedence);
        }
        return textLines;
    }
}

string quote_raw(string str)
{
    static auto re = regex(r"`", "g");
    return "`" ~ replace(str, re, "`\"`\"`") ~ "`";
}

class Grammar {
    GrammarSpecification spec;
    ParserState[ParserStateId] parserStates;
    Set!(ParserState)[ParserState][NonTerminalSymbol] gotoTable;
    ParserStateId[] emptyLookAheadSets; 
    size_t unresolvedSRConflicts;
    size_t unresolvedRRConflicts;

    @property
    bool is_valid()
    {
        return unresolvedRRConflicts == 0 && unresolvedSRConflicts == 0;
    }

    this(GrammarSpecification specification)
    {
        spec = specification;
        auto startItemKey = new GrammarItemKey(spec.productionList[0]);
        auto startLookAheadSet = new Set!(TokenSymbol)(spec.symbolTable.get_symbol(SpecialSymbols.end));
        GrammarItemSet startKernel = spec.closure([ startItemKey : startLookAheadSet]);
        parserStates[0] = new ParserState(startKernel);
        assert(parserStates[0].id == 0);
        while (true) {
            // Find a state that needs processing or quit
            ParserState unprocessedState = null;
            // Go through states in id order
            for (auto i = 0; i < parserStates.length; i++) {
                if (parserStates[i].state != ProcessedState.processed) {
                    unprocessedState = parserStates[i];
                    break;
                }
            }
            if (unprocessedState is null) break;

            auto firstTime = unprocessedState.state == ProcessedState.unProcessed;
            unprocessedState.state = ProcessedState.processed;
            auto alreadyDone = new Set!Symbol;
            // do items in order
            auto itemKeys = extract_key_set(unprocessedState.grammarItems);
            foreach (itemKey; itemKeys.elements){
                if (!itemKey.is_shiftable) continue;
                ParserState gotoState;
                auto symbolX = itemKey.nextSymbol;
                if (alreadyDone.contains(symbolX)) continue;
                alreadyDone.add(symbolX);
                auto itemSetX = spec.closure(generate_goto_kernel(unprocessedState.grammarItems, symbolX));
                auto equivalentState = find_equivalent_state(itemSetX);
                if (equivalentState is null) {
                    gotoState = new ParserState(itemSetX);
                    parserStates[gotoState.id] = gotoState;
                } else {
                    foreach (itemKey, lookAheadSet; itemSetX) {
                        if (!equivalentState.grammarItems[itemKey].contains(lookAheadSet)) {
                            equivalentState.grammarItems[itemKey].add(lookAheadSet);
                            if (equivalentState.state == ProcessedState.processed) {
                                equivalentState.state = ProcessedState.needsReprocessing;
                            }
                        }
                    }
                    gotoState = equivalentState;
                }
                if (firstTime) {
                    if (symbolX.type == SymbolType.token) {
                        unprocessedState.shiftList[symbolX] = gotoState;
                    } else {
                        assert(symbolX !in unprocessedState.gotoTable);
                        unprocessedState.gotoTable[symbolX] = gotoState;
                    }
                    if (symbolX.id == SpecialSymbols.parseError) {
                        unprocessedState.errorRecoveryState = gotoState;
                    }
                }
            }
            
        }
        for (auto i = 0; i < parserStates.length; i++) {
            auto parserState = parserStates[i];
            if (parserState.get_look_ahead_set().cardinality == 0) {
                emptyLookAheadSets ~= parserState.id;
            }
            unresolvedSRConflicts += parserState.resolve_shift_reduce_conflicts();
            unresolvedRRConflicts += parserState.resolve_reduce_reduce_conflicts();
        }
    }

    ParserState find_equivalent_state(GrammarItemSet kernel)
    {
        // TODO: check if this needs to use only kernel keys
        auto targetKeySet = get_kernel_keys(kernel);
        foreach (parserState; parserStates.byValue()) {
            if (targetKeySet == get_kernel_keys(parserState.grammarItems)) {
                return parserState;
            }
        }
        return null;
    }

    string[] generate_symbol_enum_code_text()
    {
        // TODO: determine type for DDSymbol from maximum symbol id
        string[] textLines = ["alias ushort DDSymbol;\n"];
        textLines ~= "enum DDToken : DDSymbol {";
        foreach (token; spec.symbolTable.get_special_tokens_ordered()) {
            textLines ~= format("    %s = %s,", token.name, token.id);
        }
        foreach (token; spec.symbolTable.get_tokens_ordered()) {
            textLines ~= format("    %s = %s,", token.name, token.id);
        }
        textLines ~= "}\n";
        textLines ~= "enum DDNonTerminal : DDSymbol {";
        foreach (non_terminal; spec.symbolTable.get_special_non_terminals_ordered()) {
            textLines ~= format("    %s = %s,", non_terminal.name, non_terminal.id);
        }
        foreach (non_terminal; spec.symbolTable.get_non_terminals_ordered()) {
            textLines ~= format("    %s = %s,", non_terminal.name, non_terminal.id);
        }
        textLines ~= "}\n";
        return textLines;
    }

    string[] generate_lexan_token_code_text()
    {
        string[] textLines = ["DDTokenSpec[] ddTokenSpecs;"];
        textLines ~= "static this() {";
        textLines ~= "    ddTokenSpecs = [";
        foreach (token; spec.symbolTable.get_tokens_ordered()) {
            textLines ~= format("        new DDTokenSpec(%s, %s),", quote_raw(token.name), quote_raw(token.pattern));
        }
        textLines ~= "    ];";
        textLines ~= "}";
        textLines ~= "";
        textLines ~= "string[] ddSkipRules = [";
        foreach (rule; spec.symbolTable.get_skip_rules()) {
            textLines ~= format("        %s,", quote_raw(rule));
        }
        textLines ~= "    ];\n";
        return textLines;
    }

    string[] generate_attributes_code_text()
    {
        string[] textLines = ["struct DDAttributes {"];
        textLines ~= "    DDCharLocation ddLocation;";
        textLines ~= "    string ddMatchedText;";
        auto fields = spec.symbolTable.get_field_definitions();
        if (fields.length > 0) {
            textLines ~= "    union {";
            textLines ~= "        DDSyntaxErrorData ddSyntaxErrorData;";
            foreach (field; fields) {
                textLines ~= format("        %s %s;", field.fieldType, field.fieldName);
            }
            textLines ~= "    }";
        } else {
            textLines ~= "    DDSyntaxErrorData ddSyntaxErrorData;";
        }
        textLines ~= "}\n\n";
        textLines ~= "void dd_set_attribute_value(ref DDAttributes attrs, DDToken ddToken, string text)";
        textLines ~= "{";
        Set!TokenSymbol[string] tokenSets;
        foreach(token; spec.symbolTable.get_tokens_ordered()) {
            if (token.fieldName.length > 0) {
                if (token.fieldName !in tokenSets) {
                    tokenSets[token.fieldName] = new Set!TokenSymbol(token);
                } else {
                    tokenSets[token.fieldName].add(token);
                }
            }
        }
        if (tokenSets.length > 0) {
            textLines ~= "    with (DDToken) switch (ddToken) {";
            foreach (field; fields) {
                if (field.fieldName in tokenSets) {
                    textLines ~= format("    case %s:", token_list_string(tokenSets[field.fieldName].elements));
                    if (field.conversionFunctionName.length > 0) {
                        textLines ~= format("        attrs.%s  = %s(text);", field.fieldName, field.conversionFunctionName);
                    } else {
                        textLines ~= format("        attrs.%s  = to!(%s)(text);", field.fieldName, field.fieldType);
                    }
                    textLines ~= "        break;";
                }
            }
            textLines ~= "    default:";
            textLines ~= "        // Do nothing";
            textLines ~= "    }";
        }
        textLines ~= "}\n";
        return textLines;
    }

    string[] generate_production_data_code_text()
    {
        string[] textLines = ["DDProductionData"];
        textLines ~= "dd_get_production_data(DDProduction ddProduction)";
        textLines ~= "{";
        textLines ~= "    with (DDNonTerminal) switch(ddProduction) {";
        for (auto i = 0; i < spec.productionList.length; i++) {
            auto production = spec.productionList[i];
            textLines ~= format("    case %s: return DDProductionData(%s, %s);", i, production.leftHandSide.name, production.rightHandSide.length);
        }
        textLines ~= "    default:";
        textLines ~= "        throw new Exception(\"Malformed production data table\");";
        textLines ~= "    }";
        textLines ~= "    assert(false);";
        textLines ~= "}\n";
        return textLines;
    }

    string[] generate_semantic_code_text()
    {
        string[] textLines = ["void"];
        textLines ~= "dd_do_semantic_action(ref DDAttributes ddLhs, DDProduction ddProduction, DDAttributes[] ddArgs)";
        textLines ~= "{";
        textLines ~= "    switch(ddProduction) {";
        for (auto i = 0; i < spec.productionList.length; i++) {
            auto production = spec.productionList[i];
            if (production.action.length > 0) {
                textLines ~= format("    case %s:", i);
                textLines ~= production.expanded_semantic_action;
                textLines ~= "        break;";
            }
        }
        textLines ~= "    default:";
        textLines ~= "        // Do nothing";
        textLines ~= "    }";
        textLines ~= "}\n";
        return textLines;
    }

    string[] generate_action_table_code_text()
    {
        string[] codeTextLines = [];
        codeTextLines ~= "DDParseAction dd_get_next_action(DDParserState ddCurrentState, DDToken ddToken, in DDAttributes[] ddAttributeStack)";
        codeTextLines ~= "{";
        codeTextLines ~= "    with (DDToken) switch(ddCurrentState) {";
        // Do this in state id order
        auto indent = "        ";
        for (auto i = 0; i < parserStates.length; i++) {
            auto parserState = parserStates[i];
            codeTextLines ~= format("    case %s:", parserState.id);
            foreach (line; parserState.generate_action_code_text()) {
                auto indented_line = indent ~ line;
                codeTextLines ~= indented_line;
            }
            codeTextLines ~= "        break;";
        }
        codeTextLines ~= "    default:";
        codeTextLines ~= "        throw new Exception(format(\"Invalid parser state: %s\", ddCurrentState));";
        codeTextLines ~= "    }";
        codeTextLines ~= "    assert(false);";
        codeTextLines ~= "}\n";
        return codeTextLines;
    }

    string[] generate_goto_table_code_text()
    {
        string[] codeTextLines = [];
        codeTextLines ~= "DDParserState dd_get_goto_state(DDNonTerminal ddNonTerminal, DDParserState ddCurrentState)";
        codeTextLines ~= "{";
        codeTextLines ~= "    with (DDNonTerminal) switch(ddCurrentState) {";
        // Do this in state id order
        auto keySet = extract_key_set(parserStates);
        auto indent = "        ";
        foreach (key; keySet.elements) {
            auto parserState = parserStates[key];
            if (parserState.gotoTable.length == 0) continue;
            codeTextLines ~= format("    case %s:", parserState.id);
            foreach (line; parserState.generate_goto_code_text()) {
                auto indented_line = indent ~ line;
                codeTextLines ~= indented_line;
            }
            codeTextLines ~= "        break;";
        }
        codeTextLines ~= "    default:";
        codeTextLines ~= "        throw new Exception(format(\"Malformed goto table: no entry for (%s, %s).\", ddNonTerminal, ddCurrentState));";
        codeTextLines ~= "    }";
        codeTextLines ~= "    throw new Exception(format(\"Malformed goto table: no entry for (%s, %s).\", ddNonTerminal, ddCurrentState));";
        codeTextLines ~= "}\n";
        return codeTextLines;
    }

    string[] generate_error_recovery_code_text()
    {
        string[] codeTextLines = ["bool dd_error_recovery_ok(DDParserState ddParserState, DDToken ddToken)"];
        codeTextLines ~= "{";
        codeTextLines ~= "    with (DDToken) switch(ddParserState) {";
        // Do this in state id order
        for (auto i = 0; i < parserStates.length; i++) {
            auto parserState = parserStates[i];
            if (parserState.errorRecoveryState is null) continue;
            auto errorRecoverySet = new Set!TokenSymbol;
            foreach (itemKey, lookAheadSet; parserState.errorRecoveryState.grammarItems) {
                if (itemKey.dot > 0 && itemKey.production.rightHandSide[itemKey.dot - 1].id == SpecialSymbols.parseError) {
                    errorRecoverySet.add(lookAheadSet);
                }
            }
            if (errorRecoverySet.cardinality > 0) {
                codeTextLines ~= format("    case %s:", parserState.id);
                codeTextLines ~= "        switch (ddToken) {";
                codeTextLines ~= format("        case %s:", token_list_string(errorRecoverySet.elements));
                codeTextLines ~= "            return true;";
                codeTextLines ~= "        default:";
                codeTextLines ~= "            return false;";
                codeTextLines ~= "        }";
                codeTextLines ~= "        break;";
            }
        }
        codeTextLines ~= "    default:";
        codeTextLines ~= "    }";
        codeTextLines ~= "    return false;";
        codeTextLines ~= "}\n";
        return codeTextLines;
    }

    void write_parser_code(File outputFile, string moduleName="")
    in {
        assert(outputFile.isOpen);
        assert(outputFile.size == 0);
        assert(is_valid);
    }
    body {
        if (moduleName.length > 0) {
            outputFile.writefln("module %s;\n", moduleName);
        }
        outputFile.writeln(spec.preambleCodeText);
        outputFile.writeln("import ddlib.templates;\n");
        outputFile.writeln("mixin DDParserSupport;\n");
        foreach (line; generate_symbol_enum_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_production_data_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_semantic_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_attributes_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_goto_table_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_action_table_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_error_recovery_code_text()) {
            outputFile.writeln(line);
        }
        foreach (line; generate_lexan_token_code_text()) {
            outputFile.writeln(line);
        }
        outputFile.writeln("\nmixin DDImplementParser;\n");
        outputFile.close();
    }

    string get_parser_states_description()
    {
        string str;
        for (auto i = 0; i < parserStates.length; i++) {
            str ~= parserStates[i].get_description();
        }
        return str;
    }
}
