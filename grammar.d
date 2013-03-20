module grammar.d;

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

    this() {
        mixin(set_unique_id);
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

class ParserState {
    GrammarItemSet grammarItems;
    ParserState[TokenSymbol] shiftList;
    ParserState errorRecoveryState;
    ProcessedState state;

    this(GrammarItemSet kernel) {
        grammarItems = kernel;
    }

    ShiftReduceConflict[]
    get_shift_reduce_conflicts()
    {
        ShiftReduceConflict[] conflicts;
        foreach(shiftSymbol, gotoState; shiftList) {
            foreach (item, lookAheadSet; grammarItems) {
                if (!item.is_shiftable && lookAheadSet.contains(shiftSymbol)) {
                    conflicts ~= ShiftReduceConflict(shiftSymbol, gotoState, item, lookAheadSet);
                }
            }
        }
        return conflicts;
    }

    ReduceReduceConflict[]
    get_reduce_reduce_conflicts()
    {
        ReduceReduceConflict[] conflicts;
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
                    conflicts ~= ReduceReduceConflict([key1, key2], intersection);
                }
            }
        }
        return conflicts;
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
    closure(ref GrammarItemSet itemSet)
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
