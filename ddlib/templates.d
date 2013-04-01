module ddlib.templates;

mixin template DDParserSupport() {
    import std.conv;
    import std.string;
    import std.stdio;

    import ddc = ddlib.components;
    import ddlexan = ddlib.lexan;

    alias ddc.ProductionId DDProduction;
    alias ddc.ParserStateId DDParserState;
    alias ddlexan.TokenSpec DDTokenSpec;
    alias ddlexan.CharLocation DDCharLocation;


    enum DDParseActionType { shift, reduce, accept, error };
    struct DDParseAction {
        DDParseActionType action;
        union {
            DDProduction productionId;
            DDParserState next_state;
            DDToken[] expectedTokens;
        }
    }

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
    ddError(DDToken[] expectedTokens)
    {
        auto action = DDParseAction(DDParseActionType.error);
        action.expectedTokens = expectedTokens;
        return action;
    }

    DDParseAction
    ddAccept()
    {
        return DDParseAction(DDParseActionType.accept, 0);
    }

    class DDSyntaxErrorData {
        DDToken unexpectedToken;
        string matchedText;
        DDCharLocation location;
        DDToken[] expectedTokens;
        uint skipCount;

        this(DDToken ddToken, DDAttributes ddAttrs, DDToken[] ddTokenList)
        {
            unexpectedToken = ddToken;
            matchedText = ddAttrs.ddMatchedText;
            location = ddAttrs.ddLocation;
            expectedTokens = ddTokenList;
        }

        override string toString()
        {
            auto str = format("Line %s: Syntax Error: ", location.lineNumber);
            str ~= format("found %s (\"%s\"): ", unexpectedToken, matchedText);
            str ~= format("expected %s.", expectedTokens);
            return str;
        }
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
        DDAttributes currentTokenAttributes;
        DDToken currentToken;
        DDLexicalAnalyser lexicalAnalyser;
        // Error handling data
        bool shifted;
        DDParserState lastErrorState;
        uint skipCount;

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
            dd_do_semantic_action(attrStack[stackIndex], productionId, attrs);
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
                    auto errorData = new DDSyntaxErrorData(currentToken, currentTokenAttributes, next_action.expectedTokens);
                    auto successful = recover_from_error(errorData);
                    if (!successful) {
                        stderr.writeln(errorData);
                        return false;
                    }
                }
            }
        }

        bool
        recover_from_error(DDSyntaxErrorData errorData)
        {
            auto found = false;
            auto distanceToViableState = 0;
            if (shifted) {
                lastErrorState = 0;
                skipCount = 0;
            }
            while (true) {
                for (distanceToViableState = 0; !found && distanceToViableState < stackLength; distanceToViableState++) {
                    auto candidateState = stateStack[stackIndex - distanceToViableState].state;
                    found = candidateState != lastErrorState && dd_error_recovery_ok(candidateState, currentToken);
                }
                if (found || currentToken == DDToken.ddEND) break;
                get_next_token();
                skipCount++;
            }
            errorData.skipCount = skipCount;
            if (found) {
                pop(distanceToViableState);
                lastErrorState = currentState;
                auto nextState = dd_get_goto_state(DDNonTerminal.ddERROR, currentState);
                push(DDNonTerminal.ddERROR, nextState);
                attrStack[stackIndex].ddSyntaxErrorData = errorData;
            }
            return found;
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
