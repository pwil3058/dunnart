module ddlib.components;

alias uint SymbolId;

alias uint ProductionId;

enum ParseActionType { shift, reduce, accept, error };

struct ParseAction {
    ParseActionType action;
    union {
        ProductionId productionId;
        uint next_state;
    }
}

class ProductionData(A) {
    uint id;
    SymbolId leftHandSide;
    size_t length;
    abstract void do_semantic_action(ref A ddLhsAttr, const A[] ddArgs);
}
