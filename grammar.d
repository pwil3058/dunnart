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
            symbol.firstsData = FirstsData(tokenSet, transparent);
        }
        return symbol.firstsData;
    }
}
