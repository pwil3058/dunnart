module parser;

import ddlib.components;
import ddlib.lexan;

struct StackElement {
    SymbolId symbolId;
    ParserState state;
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

    private @property ParserState
    currentState()
    {
        return stateStack[stackIndex].state;
    }

    private void
    push(SymbolId symbolId, ParserState state)
    {
        stackLength += 1;
        if (stackLength >= stateStack.length) {
            stateStack ~= new StackElement[STACK_LENGTH_INCR];
            attrStack ~= new A[STACK_LENGTH_INCR];
        }
        stateStack[stackIndex] = StackElement(symbolId, state);
    }

    private A[]
    pop(size_t count)
    {
        stackLength -= 1;
        return attrStack[stackIndex .. stackIndex + count].dup;
    }

    void
    do_shift(ParserState to_state)
    {
        push(currentToken, to_state);
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
        push(productionData.leftHandSide, nextState);
        do_semantic_action(productionId, attrs);
    }

    bool
    parse_text(string text)
    {
        stackLength = 0;
        lexicalAnalyser.set_input_text(text);
        push(SpecialSymbols.start, startState);
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
        currentTokenAttributes.ddLocation = mr.location;
        currentTokenAttributes.ddString = mr.matchedText;
        if (mr.is_valid_token) {
            auto tokenData = get_token_data(mr.tokenSpec.name);
            currentToken = tokenData.symbolId;
            if (tokenData.fieldName.length > 0) {
                set_attribute_value(currentTokenAttributes, tokenData.fieldName, mr.matchedText);
            }
        } else {
            currentToken = SpecialSymbols.lexError;
        }
    }

    abstract void set_attribute_value(ref A attrs, string fieldName, string text);
    abstract ProductionData get_production_data(ProductionId productionId);
    abstract ParserState get_goto_state(SymbolId symbolId, ParserState state) { return 10; };
    abstract void do_semantic_action(ProductionId productionId, in A[] attrs);
    abstract ParseAction get_next_action(ParserState state, SymbolId symbolId);
    abstract TokenData get_token_data(string tokenName);
}

unittest {
    struct Attr {
        CharLocation ddLocation;
        string ddString;
        union {
            int _int;
            bool _bool;
        }
    }

    void dd_do_semantic_action(ref Attr lhs, ProductionId pid, in Attr[] args)
    {
        // we need to do semantic actions outside the parsers context
        // but in the module context
        // this will be a giant switch
    }

    void dd_set_attribute_value(ref Attr attrs, string fieldName, string text)
    {
        // we need to do this outside the parsers context to avoid name
        // clashes with parser internals
    }

    class TestParser: LALRParser!Attr {
        override void set_attribute_value(ref Attr attrs, string fieldName, string text)
        {
            dd_set_attribute_value(attrs, fieldName, text);
        }

        override ProductionData get_production_data(ProductionId productionId) {
            // Use giant switch statement here as can't create static
            // as the following are not considered to be constant
            // expressions
            //static ProductionData[ProductionId] productionData = [
                //0: ProductionData(2,3),
            //];

            return ProductionData(2,3);
        }
        override ParserState get_goto_state(SymbolId symbolId, ParserState state)
        {
            // Use giant switch statement here as can't create static
            // 2 dimensional associative arrays
            return 10;
        }
        override void do_semantic_action(ProductionId productionId, in Attr[] attrs)
        {
            dd_do_semantic_action(attrStack[stackIndex], productionId, attrs);
        }
        override ParseAction get_next_action(ParserState state, SymbolId symbolId) { return ParseAction(ParseActionType.shift, 3); }
        override TokenData get_token_data(string tokenName) { return TokenData(12, ""); }
    }

    auto parser = new TestParser;
    //parser.parse_text("text");
}
