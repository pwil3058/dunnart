module parser;

import ddlib.components;
import ddlib.lexan;

struct StackElement {
    SymbolId symbolId;
    uint state;
}

class LALRParser(A) {
    static const STACK_LENGTH_INCR = 100;
    StackElement[] stateStack;
    A[] attrStack;
    size_t stackLength;
    bool shifted;
    A currentTokenAttributes;
    SymbolId currentToken;
    LexicalAnalyser lexicalAnalyser;

    private @property size_t
    stackIndex()
    {
        return stackLength - 1;
    }

    private @property uint
    currentState()
    {
        return stateStack[stackIndex].state;
    }

    private void
    incr_stack_index()
    {
        stackLength += 1;
        if (stackLength >= stateStack.length) {
            stateStack ~= new StackElement[STACK_LENGTH_INCR];
            attrStack ~= new A[STACK_LENGTH_INCR];
        }
    }

    private A[]
    pop(size_t count)
    {
        stackLength -= 1;
        return attrStack[stackIndex .. stackIndex + count].dup;
    }

    void
    do_shift(uint to_state)
    {
        incr_stack_index();
        stateStack[stackIndex] = StackElement(currentToken, to_state);
        shifted = true;
        attrStack[stackIndex] = currentTokenAttributes;
        get_next_token();
    }

    void
    do_reduce(ProductionId productionId)
    {
        auto productionData = get_production_data(productionId);
        auto attrs = pop(productionData.length);
        auto nextState = get_goto_state(productionData.leftHandSide, currentState);
        incr_stack_index();
        stateStack[stackIndex] = StackElement(productionData.leftHandSide, nextState);
        productionData.do_semantic_action(&attrStack[stackIndex], attrs);
    }

    bool
    parse_text(string text)
    {
        stackLength = 0;
        lexicalAnalyser.set_input_text(text);
        do_shift(SpecialSymbols.start, 0);
        while (true) {
            auto next_action = get_next_action(currentState, currentToken);
            final switch (next_action.action) {
                case ParseActionType.shift:
                    do_shift(next_action.next_state);
                    break;
                case ParseActionType.reduce:
                    do_reduce(next_action.productionId);
                    break;
                case ParseActionType.accept:
                    return true;
                case ParseActionType.error:
                    auto successful = recover_from_error();
                    if (!successful)
                        return false;;
            }
        }
    }

    bool
    recover_from_error()
    {
        // TODO: implement error recovery
        return false;
    }

    void
    get_next_token()
    {
        auto mr = lexicalAnalyser.advance();
        if (mr.tokenSpec is null) {
            // throw a wobbly
        } else {
            auto tokenData = get_token_data(mr.tokenSpec.name);
            currentToken = tokenData.symbolId;
            currentTokenAttributes.ddLocation = mr.location;
            if (tokenData.fieldId.length > 0) {
                set_attribute_value(currentTokenAttributes, tokenData.fieldId, mr.matchedText);
            } else {
                currentTokenAttributes.ddString = mr.matchedText;
            }
        }
    }

    abstract void set_attribute_value(ref A attrs, string fieldId, string text);
    abstract ProductionData get_production_data(uint productionId);
}

unittest {
    auto parser = new LALRParser!int;
    //parser.parse_text("text");
}
