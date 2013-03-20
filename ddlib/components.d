module ddlib.components;

alias uint ParserStateId;
ParserStateId startState = 0;

alias uint SymbolId;
enum SpecialSymbols : SymbolId { start, end, lexError, parseError };

alias uint ProductionId;

enum ParseActionType { shift, reduce, accept, error };

struct ParseAction {
    ParseActionType action;
    union {
        ProductionId productionId;
        ParserStateId next_state;
    }
}

struct ProductionData {
    SymbolId leftHandSide;
    size_t length;
} 

struct TokenData {
    SymbolId symbolId;
    string fieldName;
}

struct FieldDefinition {
    string fieldName;
    string fieldType;
    string conversionFunctionName;
}
