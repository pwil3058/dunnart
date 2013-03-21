module grammar;

import std.string;

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
        auto keys = new GrammarItemKey[grammarItems.length];
        auto i = 0;
        foreach (key; grammarItems.byKey()) {
            if (!key.is_shiftable) {
                keys[i] = key;
                i++;
            }
        }
        keys.length = i;
        for (i = 0; i < keys.length - 1; i++) {
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
}
