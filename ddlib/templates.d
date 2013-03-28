module ddlib.templates;

mixin template DDParserSupport() {
    import std.conv;
    import ddc = ddlib.components;
    import ddlexan = ddlib.lexan;

    alias ddc.ProductionId DDProduction;
    alias ddc.ParserStateId DDParserState;
    alias ddc.ParseAction DDParseAction;
    alias ddc.ParseActionType DDParseActionType;
    alias ddlexan.TokenSpec DDTokenSpec;
    alias ddlexan.CharLocation DDCharLocation;

    struct DDProductionData {
        DDNonTerminal leftHandSide;
        size_t length;
    }

    DDParseAction
    ddShift(DDParserState ddState)
    {
        return DDParseAction(DDParseActionType.shift, ddState);
    }

    DDParseAction
    ddReduce(DDProduction ddProduction)
    {
        return DDParseAction(DDParseActionType.reduce, ddProduction);
    }

    DDParseAction
    ddError()
    {
        return DDParseAction(DDParseActionType.error, 0);
    }

    DDParseAction
    ddAccept()
    {
        return DDParseAction(DDParseActionType.accept, 0);
    }
}

mixin template DDImplementParser() {
    class DDLexicalAnalyser: ddlexan.LexicalAnalyser {
        this()
        {
            super(ddTokenSpecs, ddSkipRules);
        }
    }

    class DDParser {
        struct StackElement {
            DDSymbol symbolId;
            DDParserState state;
        }
        static const STACK_LENGTH_INCR = 100;
        StackElement[] stateStack;
        DDAttributes[] attrStack;
        size_t stackLength;
        bool shifted;
        DDAttributes currentTokenAttributes;
        DDToken currentToken;
        DDLexicalAnalyser lexicalAnalyser;

        this()
        {
            lexicalAnalyser = new DDLexicalAnalyser;
        }

        private @property size_t
        stackIndex()
        {
            return stackLength - 1;
        }

        private @property DDParserState
        currentState()
        {
            return stateStack[stackIndex].state;
        }

        private void
        push(DDSymbol symbolId, DDParserState state)
        {
            stackLength += 1;
            if (stackLength >= stateStack.length) {
                stateStack ~= new StackElement[STACK_LENGTH_INCR];
                attrStack ~= new DDAttributes[STACK_LENGTH_INCR];
            }
            stateStack[stackIndex] = StackElement(symbolId, state);
        }

        private DDAttributes[]
        pop(size_t count)
        {
            stackLength -= 1;
            return attrStack[stackIndex .. stackIndex + count].dup;
        }

        void
        do_shift(DDParserState to_state)
        {
            push(currentToken, to_state);
            shifted = true;
            attrStack[stackIndex] = currentTokenAttributes;
            get_next_token();
        }

        void
        do_reduce(DDProduction productionId)
        {
            auto productionData = dd_get_production_data(productionId);
            auto attrs = pop(productionData.length);
            auto nextState = dd_get_goto_state(productionData.leftHandSide, currentState);
            push(productionData.leftHandSide, nextState);
            dd_do_semantic_action(productionId, attrs);
        }

        bool
        parse_text(string text)
        {
            stackLength = 0;
            lexicalAnalyser.set_input_text(text);
            push(DDNonTerminal.ddSTART, 0);
            while (true) {
                auto next_action = dd_get_next_action(currentState, currentToken, attrStack[0 .. stackLength]);
                with (DDParseActionType) final switch (next_action.action) {
                case shift:
                    do_shift(next_action.next_state);
                    break;
                case reduce:
                    do_reduce(next_action.productionId);
                    break;
                case accept:
                    return true;
                case error:
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
            currentTokenAttributes.ddMatchedText = mr.matchedText;
            if (mr.is_valid_token) {
                currentToken = to!(DDToken)(mr.tokenSpec.name);
                dd_set_attribute_value(currentTokenAttributes, currentToken, mr.matchedText);
            } else {
                currentToken = DDToken.ddLEXERROR;
            }
        }
    }
}
