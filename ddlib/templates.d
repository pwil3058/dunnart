// templates.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module ddlib.templates;

mixin template DDParserSupport() {
    import std.conv;
    import std.string;
    import std.stdio;

    import ddlexan = ddlib.lexan;

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

    DDParseAction ddShift(DDParserState ddState)
    {
        return DDParseAction(DDParseActionType.shift, ddState);
    }

    DDParseAction ddReduce(DDProduction ddProduction)
    {
        return DDParseAction(DDParseActionType.reduce, ddProduction);
    }

    DDParseAction ddError(DDToken[] expectedTokens)
    {
        auto action = DDParseAction(DDParseActionType.error);
        action.expectedTokens = expectedTokens;
        return action;
    }

    DDParseAction ddAccept()
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
            string str;
            if (unexpectedToken == DDToken.ddLEXERROR) {
                str = format("%s: Unexpected input: %s", location, matchedText);
            } else {
                str = format("%s: Syntax Error: ", location.lineNumber);
                if (unexpectedToken == DDToken.ddEND) {
                    str ~= "unexpected end of input: ";
                } else {
                    auto literal = dd_literal_token_string(unexpectedToken);
                    if (literal is null) {
                        str ~= format("found %s (\"%s\"): ", unexpectedToken, matchedText);
                    } else {
                        str ~= format("found \"%s\": ", literal);
                    }
                }
                str ~= format("expected %s.", expected_tokens_as_string());
            }
            return str;
        }

        string expected_tokens_as_string()
        {
            auto str = dd_literal_token_string(expectedTokens[0]);
            if (str is null) {
                str = to!(string)(expectedTokens[0]);
            }
            for (auto i = 1; i < expectedTokens.length - 1; i++) {
                auto literal = dd_literal_token_string(expectedTokens[i]);
                if (literal is null) {
                    str ~= format(", %s", to!(string)(expectedTokens[i]));
                } else {
                    str ~= format(", \"%s\"", literal);
                }
            }
            if (expectedTokens.length > 1) {
                auto literal = dd_literal_token_string(expectedTokens[$ - 1]);
                if (literal is null) {
                    str ~= format(" or %s", to!(string)(expectedTokens[$ - 1]));
                } else {
                    str ~= format(" or \"%s\"", literal);
                }
            }
            return str;
        }
    }
}

mixin template DDImplementParser() {
    string symbol_name(DDSymbol symbol) {
        string str;
        switch (symbol) {
        case 1: case 2: case 4: .. case DDToken.max:
            str = to!string(to!DDToken(symbol));
            break;
        default:
            str = to!string(to!DDNonTerminal(symbol));
        }
        return str;
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
        ddlexan.LexicalAnalyser lexicalAnalyser;
        // Error handling data
        bool shifted;
        DDParserState lastErrorState;
        uint skipCount;

        private @property
        size_t stackIndex()
        {
            return stackLength - 1;
        }

        private @property
        DDParserState currentState()
        {
            return stateStack[stackIndex].state;
        }

        private @property
        DDSymbol topOfStack()
        {
            return stateStack[stackIndex].symbolId;
        }

        private
        void push(DDSymbol symbolId, DDParserState state)
        {
            stackLength += 1;
            if (stackLength >= stateStack.length) {
                stateStack ~= new StackElement[STACK_LENGTH_INCR];
                attrStack ~= new DDAttributes[STACK_LENGTH_INCR];
            }
            stateStack[stackIndex] = StackElement(symbolId, state);
        }

        private
        DDAttributes[] pop(size_t count)
        {
            if (count == 0) return [];
            stackLength -= count;
            return attrStack[stackLength .. stackLength + count].dup;
        }

        void do_shift(DDParserState to_state)
        {
            push(currentToken, to_state);
            shifted = true;
            attrStack[stackIndex] = currentTokenAttributes;
            get_next_token();
        }

        void do_reduce(DDProduction productionId)
        {
            auto productionData = dd_get_production_data(productionId);
            auto attrs = pop(productionData.length);
            auto nextState = dd_get_goto_state(productionData.leftHandSide, currentState);
            push(productionData.leftHandSide, nextState);
            dd_do_semantic_action(attrStack[stackIndex], productionId, attrs);
        }

        bool parse_text(string text, string label="")
        {
            stackLength = 0;
            lexicalAnalyser = ddLexicalAnalyserSpecification.new_analyser(text, label);
            get_next_token();
            push(DDNonTerminal.ddSTART, 0);
            while (true) {
                auto next_action = dd_get_next_action(currentState, currentToken, attrStack[0 .. stackLength]);
                final switch (next_action.action) with (DDParseActionType) {
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

        bool recover_from_error(DDSyntaxErrorData errorData)
        {
            auto found = false;
            auto distanceToViableState = 0;
            if (shifted) {
                lastErrorState = 0;
                skipCount = 0;
            }
            while (true) {
                distanceToViableState = 0;
                while (distanceToViableState < stackLength) {
                    auto candidateState = stateStack[stackIndex - distanceToViableState].state;
                    found = candidateState != lastErrorState && dd_error_recovery_ok(candidateState, currentToken);
                    if (found) break;
                    distanceToViableState++;
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

        void get_next_token()
        {
            if (lexicalAnalyser.empty) {
                currentToken = DDToken.ddEND;
                return;
            }
            auto mr = lexicalAnalyser.front;
            currentTokenAttributes.ddLocation = mr.location;
            currentTokenAttributes.ddMatchedText = mr.matchedText;
            if (mr.is_valid_token) {
                currentToken = to!(DDToken)(mr.tokenSpec.name);
                dd_set_attribute_value(currentTokenAttributes, currentToken, mr.matchedText);
            } else {
                currentToken = DDToken.ddLEXERROR;
            }
            lexicalAnalyser.popFront();
        }
    }
}
