module ddlib.components;

alias uint ParserStateId;
ParserStateId startState = 0;

alias uint ProductionId;

enum ParseActionType { shift, reduce, accept, error };

struct ParseAction {
    ParseActionType action;
    union {
        ProductionId productionId;
        ParserStateId next_state;
    }
}
