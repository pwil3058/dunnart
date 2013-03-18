module grammar.d;

import ddlib.components;
import symbols;
import sets;

alias string Predicate;
alias string SemanticAction;

class Production {
    ProductionId id;
    NonTerminalSymbol leftHandSide;
    Symbol[] rightHandSide;
    Associativity associativity;
    Precedence    precedence;
    Predicate predicate;
    SemanticAction action;

    @property size_t
    length()
    {
        return rightHandSide.length;
    }
}

class GrammarItem {
    Production production;
    uint dot;
    Set!TokenSymbol lookAheadSet;
    invariant () {
        assert(dot <= production.rightHandSide.length);
    }

    this(Production production)
    {
        this.production = production;
    }

    GrammarItem
    clone()
    {
        auto cloned = new GrammarItem(production);
        cloned.dot = dot;
        cloned.lookAheadSet = lookAheadSet.clone();
        return cloned;
    }

    GrammarItem
    clone_shifted()
    {
        if (dot > production.rightHandSide.length) {
            return null;
        }
        auto cloned = clone();
        cloned.dot++;
        return cloned;
    }

    @property bool
    is_kernel_item()
    {
        return dot > 0 || production.leftHandSide.id == SpecialSymbols.start;
    }

    bool
    is_next_symbol(Symbol symbol)
    {
        return dot < production.rightHandSide.length && production.rightHandSide[dot] == symbol;
    }

    override hash_t
    toHash()
    {
        return production.id * (dot + 1);
    }

    override bool
    opEquals(Object o)
    {
        GrammarItem other = cast(GrammarItem) o;
        return production.id == other.production.id && dot == other.dot;
    }

    override int
    opCmp(Object o)
    {
        GrammarItem other = cast(GrammarItem) o;
        if (production.id == other.production.id) {
            return dot - other.dot;
        }
        return production.id - other.production.id;
    }
}

Set!GrammarItem
extract_kernel(Set!GrammarItem itemset)
{
    auto kernel = new Set!GrammarItem;
    foreach (grammarItem; itemset.elements) {
        if (grammarItem.is_kernel_item) {
            kernel.add(grammarItem.clone());
        }
    }
    return kernel;
}

Set!GrammarItem
generate_goto_kernel(Set!GrammarItem itemset, Symbol symbol)
{
    auto goto_kernel = new Set!GrammarItem;
    foreach (grammarItem; itemset.elements) {
        if (grammarItem.is_next_symbol(symbol)) {
            goto_kernel.add(grammarItem.clone_shifted());
        }
    }
    return goto_kernel;
}

enum ProcessedState { unProcessed, needsReprocessing, processed };

class ParserState {
    Set!GrammarItem grammarItems;
    ProcessedState state;

    this(Set!GrammarItem kernel) {
        grammarItems = kernel;
    }
}

class GrammarSpecification {
    SymbolTable symbolTable;
    Production[] productionList;

    this() {
        symbolTable = new SymbolTable;
        auto dummyProd = new Production;
        dummyProd.id = 0;
        dummyProd.leftHandSide = symbolTable.get_symbol(SpecialSymbols.start);
        // Set the right hand side when start symbol is known.
        productionList = [dummyProd];
    }

    this(SymbolTable symbolTable) {
        Production dummyProd;
        dummyProd.id = 0;
        dummyProd.leftHandSide = symbolTable.get_symbol(SpecialSymbols.start);
        // Set the right hand side when start symbol is known.
        productionList = [dummyProd];
        this.symbolTable = symbolTable;
    }

    void
    add_production(Production newProdn)
    {
        if (productionList.length == 1) {
            productionList[0].rightHandSide = [newProdn.leftHandSide];
        }
        newProdn.id = cast(ProductionId) productionList.length;
        productionList ~= newProdn;
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

                    transparent = transparent || (production.rightHandSide.length == 0);
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
}
