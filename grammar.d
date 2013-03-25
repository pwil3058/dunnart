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

    @property const size_t
    length()
    {
        return rightHandSide.length;
    }

    @property string
    expanded_predicate()
    {
        static auto stackAttr_re = regex(r"\$(\d+)", "g");
        auto replaceWith = format("ddAttributeStack[$$ - %s + $1]", rightHandSide.length + 1);
        return replace(predicate, stackAttr_re, replaceWith);
    }

    override string
    toString()
    {
        // This is just for use in generated code comments
        if (rightHandSide.length == 0) {
            return format("%s: <empty>", leftHandSide.name);
        }
        auto str = format("%s:", leftHandSide.name);
        foreach (symbol; rightHandSide) {
            str ~= format(" %s", symbol);
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
        cloned.dot++;
        return cloned;
    }

    @property bool
    is_kernel_item()
    {
        return dot > 0 || production.leftHandSide.id == SpecialSymbols.start;
    }

    @property bool
    is_shiftable()
    {
        return dot < production.length;
    }

    @property Symbol
    nextSymbol()
    in {
        assert(is_shiftable);
    }
    body {
        return production.rightHandSide[dot];
    }

    @property Symbol[]
    tail()
    in {
        assert(is_shiftable);
    }
    body {
        return production.rightHandSide[dot + 1 .. $];
    }

    bool
    is_next_symbol(Symbol symbol)
    {
        return is_shiftable && nextSymbol == symbol;
    }

    override hash_t
    toHash()
    {
        return production.id * (dot + 1);
    }

    override bool
    opEquals(Object o)
    {
        GrammarItemKey other = cast(GrammarItemKey) o;
        return production.id == other.production.id && dot == other.dot;
    }

    override int
    opCmp(Object o)
    {
        GrammarItemKey other = cast(GrammarItemKey) o;
        if (production.id == other.production.id) {
            return dot - other.dot;
        }
        return production.id - other.production.id;
    }
}

alias Set!(TokenSymbol)[GrammarItemKey] GrammarItemSet;

Set!GrammarItemKey
get_kernel_keys(GrammarItemSet itemset)
{
    auto keySet = new Set!GrammarItemKey;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (grammarItemKey.is_kernel_item) {
            keySet.add(grammarItemKey);
        }
    }
    return keySet;
}

Set!GrammarItemKey
get_reducible_keys(GrammarItemSet itemset)
{
    auto keySet = new Set!GrammarItemKey;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (!grammarItemKey.is_shiftable) {
            keySet.add(grammarItemKey);
        }
    }
    return keySet;
}

GrammarItemSet
extract_kernel(GrammarItemSet itemset)
{
    GrammarItemSet kernel;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (grammarItemKey.is_kernel_item) {
            kernel[grammarItemKey] = lookAheadSet.clone();
        }
    }
    return kernel;
}

GrammarItemSet
generate_goto_kernel(GrammarItemSet itemset, Symbol symbol)
{
    GrammarItemSet goto_kernel;
    foreach (grammarItemKey, lookAheadSet; itemset) {
        if (grammarItemKey.is_next_symbol(symbol)) {
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

bool
trivially_true(Predicate predicate)
{
    return strip(predicate).length == 0;
}

class ParserState {
    mixin UniqueId!(ParserStateId);
    GrammarItemSet grammarItems;
    ParserState[TokenSymbol] shiftList;
    ParserState errorRecoveryState;
    ProcessedState state;
    ShiftReduceConflict[] shiftReduceConflicts;
    ReduceReduceConflict[] reduceReduceConflicts;

    this(GrammarItemSet kernel) {
        mixin(set_unique_id);
        grammarItems = kernel;
    }

    size_t
    resolve_shift_reduce_conflicts()
    {
        // Do this in two stages to obviate problems modifyin shiftList
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

    size_t
    resolve_reduce_reduce_conflicts()
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

    string[]
    generate_code_text()
    {
        string[] codeTextLines = ["switch (ddToken) {"];
        foreach (token, parserState; shiftList) {
            codeTextLines ~= format("    case %s: return ddShift(%s);", token.name, parserState.id);
        }
        auto itemKeys = get_reducible_keys(grammarItems);
        if (itemKeys.cardinality > 0) {
            struct Pair { Set!TokenSymbol lookAheadSet; Set!GrammarItemKey productionSet; };
            Pair[] pairs;
            auto combinedLookAhead = new Set!TokenSymbol;
            foreach (itemKey; itemKeys.elements) {
                combinedLookAhead.add(grammarItems[itemKey]);
            }
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
                auto tokens = pair.lookAheadSet.elements;
                auto caseline = format("    case %s", tokens[0].name);
                foreach (token; tokens[1 .. $]) {
                    caseline ~= format(", %s", token.name);
                }
                caseline ~= ":";
                codeTextLines ~= caseline;
                auto keys = pair.productionSet.elements;
                if (trivially_true(keys[0].production.predicate)) {
                    assert(keys.length == 1);
                    if (keys[0].production.id == 0) {
                        codeTextLines ~= "        return ddAccept;";
                    } else {
                        codeTextLines ~= format("        // %s", keys[0].production);
                        codeTextLines ~= format("        return ddReduce(%s);", keys[0].production.id);
                    }
                } else {
                    codeTextLines ~= format("        if (%s) {", keys[0].production.expanded_predicate);
                    codeTextLines ~= format("            // %s", keys[0].production);
                    codeTextLines ~= format("            return ddReduce(%s);", keys[0].production.id);
                    if (keys.length == 1) {
                        codeTextLines ~= "        } else {";
                        codeTextLines ~= "            return ddError;";
                        codeTextLines ~= "        }";
                        continue;
                    }
                    for (auto i = 1; i < keys.length - 1; i++) {
                        assert(!trivially_true(keys[i].production.predicate));
                        codeTextLines ~= format("        } else if (%s) {", keys[i].production.expanded_predicate);
                        codeTextLines ~= format("            // %s", keys[0].production);
                        codeTextLines ~= format("            return ddReduce(%s);", keys[i].production.id);
                    }
                    if (trivially_true(keys[$ - 1].production.predicate)) {
                        codeTextLines ~= "        } else {";
                        if (keys[$ - 1].production.id == 0) {
                            codeTextLines ~= "        return ddAccept;";
                        } else {
                            codeTextLines ~= format("            // %s", keys[0].production);
                            codeTextLines ~= format("            return ddReduce(%s);", keys[$ - 1].production.id);
                        }
                        codeTextLines ~= "        }";
                    } else {
                        codeTextLines ~= format("        } else if (%s) {", keys[$ - 1].production.expanded_predicate);
                        codeTextLines ~= format("            // %s", keys[0].production);
                        codeTextLines ~= format("            return ddReduce(%s);", keys[$ - 1].production.id);
                        codeTextLines ~= "        } else {";
                        codeTextLines ~= "            return ddError;";
                        codeTextLines ~= "        }";
                    }
                }
            }
        }
        codeTextLines ~= "    default:";
        codeTextLines ~= "        return ddError;";
        codeTextLines ~= "}";
        return codeTextLines;
    }
}

class GrammarSpecification {
    SymbolTable symbolTable;
    Production[ProductionId] productionList;

    this() {
        this(new SymbolTable);
    }

    this(SymbolTable symbolTable) {
        auto dummyProd = new Production;
        assert(dummyProd.id == 0);
        dummyProd.leftHandSide = symbolTable.get_symbol(SpecialSymbols.start);
        // Set the right hand side when start symbol is known.
        productionList[dummyProd.id] = dummyProd;
        this.symbolTable = symbolTable;
    }

    void
    add_production(Production newProdn)
    {
        if (newProdn.id == 1) {
            productionList[0].rightHandSide = [newProdn.leftHandSide];
        }
        productionList[newProdn.id] = newProdn;
    }

    Set!TokenSymbol
    FIRST(Symbol[] symbolString, TokenSymbol token)
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

    FirstsData
    get_firsts_data(Symbol symbol)
    {
        if (symbol.firstsData is null ) {
            auto tokenSet = new Set!TokenSymbol;
            auto transparent = false;
            if (symbol.type == SymbolType.token) {
                tokenSet.add(symbol);
            } else if (symbol.type == SymbolType.nonTerminal) {
                foreach (production; productionList) {
                    if (production.leftHandSide != symbol) continue;

                    transparent = transparent || (production.length == 0);
                    foreach (rhsSymbol; production.rightHandSide) {
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

    GrammarItemSet
    closure(GrammarItemSet itemSet)
    {
        bool additions_made;
        do {
            additions_made = false;
            foreach (grammarItemKey, lookAheadSet; itemSet) {
                if (!grammarItemKey.is_shiftable || grammarItemKey.nextSymbol.type != SymbolType.nonTerminal) continue;
                auto prospectiveLhs = grammarItemKey.nextSymbol;
                foreach (lookAheadSymbol; lookAheadSet.elements) {
                    auto firsts = FIRST(grammarItemKey.tail, lookAheadSymbol);
                    foreach (production; productionList) {
                        if (prospectiveLhs != production.leftHandSide) continue;
                        auto prospectiveKey = new GrammarItemKey(production);
                        if (prospectiveKey in itemSet) {
                            if (!itemSet[prospectiveKey].contains(firsts)) {
                                itemSet[prospectiveKey].add(firsts);
                                additions_made = true;
                            }
                        } else {
                            itemSet[prospectiveKey] = firsts.clone();
                            additions_made = true;
                        }
                    }
                }
            }
        } while (additions_made);
        return itemSet;
    }
}

class Grammar {
    GrammarSpecification spec;
    ParserState[ParserStateId] parserStates;
    Set!(ParserState)[ParserState][NonTerminalSymbol] gotoTable;
    size_t unresolvedSRConflicts;
    size_t unresolvedRRConflicts;

    @property bool
    valid()
    {
        return unresolvedRRConflicts == 0 && unresolvedSRConflicts == 0;
    }

    this(GrammarSpecification specification)
    {
        spec = specification;
        debug(Grammar) writefln("Specification: %s Tokens; %s NonTerminals; %s Productions", spec.symbolTable.tokenCount, spec.symbolTable.nonTerminalCount, spec.productionList.length);
        auto startItemKey = new GrammarItemKey(spec.productionList[0]);
        auto startLookAheadSet = new Set!(TokenSymbol)(spec.symbolTable.get_symbol(SpecialSymbols.end));
        GrammarItemSet startKernel = [ startItemKey : startLookAheadSet];
        parserStates[0] = new ParserState(startKernel);
        assert(parserStates[0].id == 0);
        while (true) {
            // Find a state that needs processing or quit
            ParserState unprocessedState = null;
            foreach (candidateState; parserStates.byValue()) {
                if (candidateState.state != ProcessedState.processed) {
                    unprocessedState = candidateState;
                    break;
                }
            }
            if (unprocessedState is null) break;

            auto firstTime = unprocessedState.state == ProcessedState.unProcessed;
            unprocessedState.state = ProcessedState.processed;
            auto fullItemSet = spec.closure(extract_kernel(unprocessedState.grammarItems));
            foreach (itemKey; fullItemSet.byKey()){
                if (!itemKey.is_shiftable) continue;
                ParserState gotoState;
                auto symbolX = itemKey.nextSymbol;
                auto kernelX = generate_goto_kernel(fullItemSet, symbolX);
                auto equivalentState = find_equivalent_state(kernelX);
                if (equivalentState is null) {
                    gotoState = new ParserState(kernelX);
                    parserStates[gotoState.id] = gotoState;
                } else {
                    foreach (itemKey, lookAheadSet; kernelX) {
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
                        if (symbolX !in gotoTable || gotoState !in gotoTable[symbolX]) {
                            gotoTable[symbolX] = [gotoState: new Set!(ParserState)(unprocessedState)];
                        } else {
                            gotoTable[symbolX][gotoState].add(unprocessedState);
                        }
                    }
                    if (symbolX.id == SpecialSymbols.parseError) {
                        unprocessedState.errorRecoveryState = gotoState;
                    }
                }
            }
            
        }
        foreach (parserState; parserStates) {
            unresolvedSRConflicts += parserState.resolve_shift_reduce_conflicts();
            unresolvedRRConflicts += parserState.resolve_reduce_reduce_conflicts();
        }
    }

    ParserState
    find_equivalent_state(GrammarItemSet kernel)
    {
        // TODO: check if this needs to be this complex
        auto targetKeySet = get_kernel_keys(kernel);
        foreach (parserState; parserStates.byValue()) {
            if (targetKeySet == get_kernel_keys(parserState.grammarItems)) {
                return parserState;
            }
        }
        return null;
    }

    string[]
    generate_action_table_code_text()
    {
        string[] codeTextLines = ["DDParserAction"];
        codeTextLines ~= "dd_get_next_action(DDParserState ddCurrentState, DDToken ddToken, in DDAttributes[] ddAttributeStack)";
        codeTextLines ~= "{";
        codeTextLines ~= "    switch(ddCurrentState) {";
        foreach (parserState; parserStates) {
            codeTextLines ~= format("        case %s:", parserState.id);
            auto indent = "            ";
            foreach (line; parserState.generate_code_text()) {
                auto indented_line = indent ~ line;
                codeTextLines ~= indented_line;
            }
            codeTextLines ~= "            break;";
        }
        codeTextLines ~= "        default:";
        codeTextLines ~= "            return ddError;";
        codeTextLines ~= "    }";
        codeTextLines ~= "    assert(false);";
        codeTextLines ~= "}";
        return codeTextLines;
    }

    string[]
    generate_goto_table_code_text()
    {
        string[] codeTextLines = ["DDParserState"];
        codeTextLines ~= "dd_get_goto_state(DDNonTerminal ddNonTerminal, DDParserState ddCurrentState)";
        codeTextLines ~= "{";
        codeTextLines ~= "    switch(ddNonTerminal) {";
        foreach (nonTerminal, stateGotoData; gotoTable) {
            codeTextLines ~= format("        case DDNonTerminal.%s:", nonTerminal.name);
            codeTextLines ~= "            switch(ddCurrentState) {";
            foreach (gotoState, fromStateSet; stateGotoData) {
                auto fromStates = fromStateSet.elements;
                auto caseline = format("                case %s", fromStates[0].id);
                foreach (token; fromStates[1 .. $]) {
                    caseline ~= format(", %s", token.id);
                }
                caseline ~= ":";
                codeTextLines ~= caseline;
                codeTextLines ~= format("                    return %s;", gotoState.id);
            }
            codeTextLines ~= "                default:";
            codeTextLines ~= "                    ddFatalError();";
            codeTextLines ~= "            }";
            codeTextLines ~= "            break;";
        }
        codeTextLines ~= "        default:";
        codeTextLines ~= "            ddFatalError();";
        codeTextLines ~= "    }";
        codeTextLines ~= "    assert(false);";
        codeTextLines ~= "}";
        return codeTextLines;
    }
}
