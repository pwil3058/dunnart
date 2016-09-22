// templates.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// This file is part of grallina and dunnart.
//
// grallina and dunnart are free software; you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version, with
// some exceptions, please read the COPYING file.
//
// grallina is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with grallina; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110, USA

module ddlib.templates;

mixin template DDParserSupport() {
    import std.conv;
    import std.string;
    import std.stdio;
    import std.regex;

    import ddlexan = ddlib.lexan;

    alias ddlexan.LiteralLexeme!DDHandle DDLiteralLexeme;
    template DDRegexLexeme(DDHandle handle, string script) {
        static  if (script[0] == '^') {
            enum DDRegexLexeme = ddlexan.RegexLexeme!(DDHandle, Regex!char)(handle, regex(script));
        } else {
            enum DDRegexLexeme = ddlexan.RegexLexeme!(DDHandle, Regex!char)(handle, regex("^" ~ script));
        }
    }
    alias ddlexan.LexicalAnalyser!(DDHandle, Regex!char) DDLexicalAnalyser;
    alias ddlexan.CharLocation DDCharLocation;
    alias ddlexan.Token!DDHandle DDToken;

    enum DDParseActionType { SHIFT, REDUCE, ACCEPT };
    struct DDParseAction {
        DDParseActionType action;
        union {
            DDProduction production_id;
            DDParserState next_state;
        }
    }

    template dd_shift(DDParserState dd_state) {
        enum dd_shift = DDParseAction(DDParseActionType.SHIFT, dd_state);
    }

    template dd_reduce(DDProduction dd_production) {
        enum dd_reduce = DDParseAction(DDParseActionType.REDUCE, dd_production);
    }

    template dd_accept() {
        enum dd_accept = DDParseAction(DDParseActionType.ACCEPT, 0);
    }

    struct DDProductionData {
        DDNonTerminal left_hand_side;
        size_t length;
    }

    class DDSyntaxError: Exception {
        DDHandle[] expected_tokens;

        this(DDHandle[] expected_tokens, string file=__FILE__, size_t line=__LINE__, Throwable next=null)
        {
            this.expected_tokens = expected_tokens;
            string msg = format("Syntax Error: expected  %s.", expected_tokens);
            super(msg, file, line, next);
        }
    }

    class DDSyntaxErrorData {
        DDHandle unexpected_token;
        string matched_text;
        DDCharLocation location;
        DDHandle[] expected_tokens;
        long skipped_count;

        this(DDHandle dd_token, DDAttributes dd_attrs, DDHandle[] dd_token_list)
        {
            unexpected_token = dd_token;
            matched_text = dd_attrs.dd_matched_text;
            location = dd_attrs.dd_location;
            expected_tokens = dd_token_list;
            skipped_count = -1;
        }

        override string toString()
        {
            string str;
            if (unexpected_token == DDHandle.ddINVALID_TOKEN) {
                str = format("%s: Unexpected input: %s", location, matched_text);
            } else {
                str = format("%s: Syntax Error: ", location.line_number);
                if (unexpected_token == DDHandle.ddEND) {
                    str ~= "unexpected end of input: ";
                } else {
                    auto literal = dd_literal_token_string(unexpected_token);
                    if (literal is null) {
                        str ~= format("found %s (\"%s\"): ", unexpected_token, matched_text);
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
            auto str = dd_literal_token_string(expected_tokens[0]);
            if (str is null) {
                str = to!(string)(expected_tokens[0]);
            } else {
                str = format("\"%s\"", str);
            }
            for (auto i = 1; i < expected_tokens.length - 1; i++) {
                auto literal = dd_literal_token_string(expected_tokens[i]);
                if (literal is null) {
                    str ~= format(", %s", to!(string)(expected_tokens[i]));
                } else {
                    str ~= format(", \"%s\"", literal);
                }
            }
            if (expected_tokens.length > 1) {
                auto literal = dd_literal_token_string(expected_tokens[$ - 1]);
                if (literal is null) {
                    str ~= format(" or %s", to!(string)(expected_tokens[$ - 1]));
                } else {
                    str ~= format(" or \"%s\"", literal);
                }
            }
            return str;
        }
    }
}

mixin template DDImplementParser() {
    import std.stdio;

    struct DDParseStack {
        struct StackElement {
            DDSymbol symbol_id;
            DDParserState state;
        }
        static const STACK_LENGTH_INCR = 100;
        StackElement[] state_stack;
        DDAttributes[] attr_stack;
        size_t height;
        DDParserState last_error_state;

        invariant() {
            assert(state_stack.length == attr_stack.length);
            assert(height <= state_stack.length);
        }

        private @property
        size_t index()
        {
            return height - 1;
        }

        private @property
        DDParserState current_state()
        {
            return state_stack[index].state;
        }

        private @property
        DDSymbol top_symbol()
        {
            return state_stack[index].symbol_id;
        }

        private @property
        ref DDAttributes top_attributes()
        {
            return attr_stack[index];
        }

        private @property
        DDAttributes[] attributes_stack()
        {
            return attr_stack[0..height];
        }

        private
        void push(DDSymbol symbol_id, DDParserState state)
        {
            height += 1;
            if (height >= state_stack.length) {
                state_stack ~= new StackElement[STACK_LENGTH_INCR];
                attr_stack ~= new DDAttributes[STACK_LENGTH_INCR];
            }
            state_stack[index] = StackElement(symbol_id, state);
        }

        private
        void push(DDHandle dd_token, DDParserState state, DDAttributes attrs)
        {
            push(dd_token, state);
            attr_stack[index] = attrs;
            last_error_state = 0; // Reset the last error state on shift
        }

        private
        void push(DDSymbol symbol_id, DDParserState state, DDSyntaxErrorData error_data)
        {
            push(symbol_id, state);
            attr_stack[index].dd_syntax_error_data = error_data;
        }

        private
        DDAttributes[] pop(size_t count)
        {
            if (count == 0) return [];
            height -= count;
            return attr_stack[height..height + count].dup;
        }

        private
        void reduce(DDProduction production_id, void delegate(string, string) dd_inject)
        {
            auto productionData = dd_get_production_data(production_id);
            auto attrs = pop(productionData.length);
            auto nextState = dd_get_goto_state(productionData.left_hand_side, current_state);
            push(productionData.left_hand_side, nextState);
            dd_do_semantic_action(top_attributes, production_id, attrs, dd_inject);
        }

        private
        int find_viable_recovery_state(DDHandle current_token)
        {
            int distance_to_viable_state = 0;
            while (distance_to_viable_state < height) {
                auto candidate_state = state_stack[index - distance_to_viable_state].state;
                if (candidate_state != last_error_state && dd_error_recovery_ok(candidate_state, current_token)) {
                    last_error_state = candidate_state;
                    return distance_to_viable_state;
                }
                distance_to_viable_state++;
            }
            return -1; /// Failure
        }
    }

    bool dd_parse_text(string text, string label="")
    {
        auto tokens = dd_lexical_analyser.injectable_token_forward_range(text, label, DDHandle.ddEND);
        auto parse_stack = DDParseStack();
        parse_stack.push(DDNonTerminal.ddSTART, 0);
        auto token = tokens.moveFront();
        with (parse_stack) with (DDParseActionType) {
        try_again:
            try {
                while (true) {
                    auto next_action = dd_get_next_action(current_state, token.handle, attributes_stack);
                    while (next_action.action == REDUCE) {
                        reduce(next_action.production_id, &tokens.inject);
                        next_action = dd_get_next_action(current_state, token.handle, attributes_stack);
                    }
                    if (next_action.action == SHIFT) {
                        push(token.handle, next_action.next_state, DDAttributes(token));
                        token = tokens.moveFront();
                    } else if (next_action.action == ACCEPT) {
                        return true;
                    }
                }
            } catch (ddlexan.LexanInvalidToken edata) {
                token = new DDToken(DDHandle.ddINVALID_TOKEN, edata.unexpected_text, edata.location);
                goto try_again;
            } catch (DDSyntaxError edata) {
                auto error_data = new DDSyntaxErrorData(token.handle, DDAttributes(token), edata.expected_tokens);
                auto distance_to_viable_state = find_viable_recovery_state(token.handle);
                while (distance_to_viable_state < 0 && token.handle != DDHandle.ddEND) {
                    token = tokens.moveFront();
                    error_data.skipped_count++;
                    distance_to_viable_state = find_viable_recovery_state(token.handle);
                }
                if (distance_to_viable_state >= 0) {
                    pop(distance_to_viable_state);
                    push(DDNonTerminal.ddERROR, dd_get_goto_state(DDNonTerminal.ddERROR, current_state), error_data);
                    goto try_again;
                } else {
                    stderr.writeln(error_data);
                    return false;
                }
            }
        }
        stderr.writeln("Unexpected end of input.");
        return false;
    }
}
