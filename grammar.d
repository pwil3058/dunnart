module grammar.d;

import ddlib.components;
import symbols;

alias string Predicate;
alias string SemanticAction;

struct Production {
    ProductionId id;
    SymbolId leftHandSide;
    SymbolId[] rightHandSide;
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
        Production dummyProd;
        dummyProd.id = 0;
        dummyProd.leftHandSide = SpecialSymbols.start;
        // Set the right hand side when start symbol is known.
        productionList = [dummyProd];
        symbolTable = new SymbolTable;
    }

    this(SymbolTable symbolTable) {
        Production dummyProd;
        dummyProd.id = 0;
        dummyProd.leftHandSide = SpecialSymbols.start;
        // Set the right hand side when start symbol is known.
        productionList = [dummyProd];
        this.symbolTable = symbolTable;
    }

    void
    add_production(Production newProdn)
    {
        if (productionList.length == 1) {
            productionList[0].rightHandSide = new SymbolId[newProdn.leftHandSide];
        }
        newProdn.id = cast(ProductionId) productionList.length;
        productionList ~= newProdn;
    }
}
