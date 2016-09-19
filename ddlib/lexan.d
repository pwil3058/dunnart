// lexan.d
//
// Copyright Peter Williams 2014 <pwil3058@bigpond.net.au>.
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
/**
 * Provides a simple mechanism for creating lexical analysers. The lexicon
 * to be analysed is specified using a combination of literal lexemes
 * (for reserved words, operators, etc.), regex lexemes (for names, numbers, etc.)
 * and skip (white space) regexes.
 *
 * The resulting lexical analyser can be used to create two types of
 * token input range:
 *  - a simple token input range for a single string
 *  - an injectable input range which starts out with a single string
 * but may have arbitrary strings injected into it at any time e.g.
 * implementation of C include files.
 *
 * The string being analysed and all of the state data for the progress
 * of the analysis are held within the generated input ranges and a
 * single lexical analyser can be used to analyse several strings
 * simultaneously.  I.e. only one copy of the analyser for any lexicon
 * is needed and it acts as a token input range factory.
 *
 * The token input ranges are light weight as they do not carry their
 * own copy of the specification just a reference to the lexical analyser
 * which provides the necessary services via a defined interface.
 *
 * Copyright: Copyright Peter Williams 2014-.
 *
 * License:   $(WEB gnu.org/licenses/lgpl.html, GNU Lesser General Public License 3.0).
 *
 * Authors:   Peter Williams
 *
 * Source: $(DUNNARTSRC ddlb.lexan.d)
 */

module ddlib.lexan;

import std.regex;
import std.ascii;
import std.string;

/**
 * This is a base exception from which all Lexan exceptions are derived.
 * It provides a mechanism to catch any Lexan exception.
 */
class LexanException: Exception {
    this(string message, string file=__FILE__, size_t line=__LINE__, Throwable next=null)
    {
        super("LexAn Error:" ~ message, file, line, next);
    }
}

/**
 * This exception is thrown if two literal lexemes have the same pattern
 * and should not be caught. It indicates that there is an error in the
 * specification that needs to be fixed before a usable lexical analyser
 * can be created.  This will be thrown during the initial phase.
 */
class LexanDuplicateLiteralPattern: LexanException {
    string duplicate_pattern; /// the duplicated pattern

    this(string name, string file=__FILE__, size_t line=__LINE__, Throwable next=null)
    {
        duplicate_pattern = name;
        super(format("Duplicated literal specification: \"%s\".", name), file, line, next);
    }
}

/**
 * This exception is thrown if two regex lexemes match the same string
 * and should not be caught. It indicates that there is an error in the
 * specification that needs to be fixed before a usable lexical analyser
 * can be created. It is thrown if such a situation arises while analysing
 * a string and will not be thrown during the initialization phase.
 */
class LexanMultipleRegexMatches(H): LexanException {
    string matched_text; /// the piece of text that was matched
    H[] handles; /// the handles of the regex lexemes that made the match
    CharLocation location;

    this(HandleAndText!(H)[] hats, CharLocation locn, string file=__FILE__, size_t line=__LINE__, Throwable next=null)
    {
        matched_text = hats[0].text;
        foreach (hat; hats) {
            handles ~= hat.handle;
        }
        string msg = format("Regexes : %s: all match \"%s\" at %s.", handles, matched_text, locn);
        super(msg, file, line, next);
    }
}

/**
 * This exception is raised during analysis of a provided text when
 * characters are encountered that:
 *      - are not skipped by the skip regexes,
 *      - do not matche any of the literal lexemes' patterns, and
 *      - are not matched by any of the regex lexems.
 * It contains data about the nature and location of the problematic
 * characters and leaves the token input range that threw it in a usable
 * state in that it is in a position to provide a valid token or is empty.
 *
 * It is safe to catch this exception as it concerns an error in the
 * analysed text not the lexical analyser and client can then either
 * abandon the analysis or continue analysing the remainder of the
 * text as best suits their needs.
 */
class LexanInvalidToken: LexanException {
    string unexpected_text;
    CharLocation location;

    this(string utext, CharLocation locn, string file=__FILE__, size_t line=__LINE__, Throwable next=null)
    {
        unexpected_text = utext;
        location = locn;
        string msg = format("Invalid Iput: \"%s\" at %s.", utext, locn);
        super(msg, file, line, next);
    }
}

/**
 * A struct for defining literal lexemes.
 * Example:
 * ---
 * enum MyTokens { IF, THEN, ELSE, PLUS, VARName, ........}
 *
 * static auto my_literals = [
 *      LiteralLexeme!MyTokens(IF, "if"),
 *      LiteralLexeme!MyTokens(THEN, "then"),
 *      LiteralLexeme!MyTokens(ELSE, "else"),
 *      LiteralLexeme!MyTokens(PLUS, "+"),
 * ]
 * ---
 */
struct LiteralLexeme(H) {
    H handle; /// a unique handle for this lexeme
    string pattern; /// the text pattern that the lexeme represents

    @property
    size_t length()
    {
        return pattern.length;
    }

    @property
    bool is_valid()
    {
        return pattern.length > 0;
    }
}
unittest {
    LiteralLexeme!(int) el;
    assert(!el.is_valid);
    static auto ll = LiteralLexeme!(int)(6, "six");
    assert(ll.is_valid);
}

struct RegexLexeme(H, RE) {
    H handle;
    RE re;

    @property
    bool is_valid()
    {
        return !re.empty;
    }
}

template CtRegexLexeme(H, H handle, string script) {
    static  if (script[0] == '^') {
        enum CtRegexLexeme = RegexLexeme!(H, StaticRegex!char)(handle, ctRegex!(script));
    } else {
        enum CtRegexLexeme = RegexLexeme!(H, StaticRegex!char)(handle, ctRegex!("^" ~ script));
    }
}

template EtRegexLexeme(H, H handle, string script) {
    static  if (script[0] == '^') {
        enum EtRegexLexeme = RegexLexeme!(H, Regex!char)(handle, regex(script));
    } else {
        enum EtRegexLexeme = RegexLexeme!(H, Regex!char)(handle, regex("^" ~ script));
    }
}

unittest {
    RegexLexeme!(int, StaticRegex!char) erel;
    assert(!erel.is_valid);
    static auto rel = RegexLexeme!(int, StaticRegex!char)(12, ctRegex!("^twelve"));
    assert(rel.is_valid);
    RegexLexeme!(int, Regex!char) edrel;
    assert(!edrel.is_valid);
    auto drel =  RegexLexeme!(int, Regex!char)(12, regex("^twelve"));
    assert(drel.is_valid);
    auto tdrel = EtRegexLexeme!(int, 13, "^twelve");
}

private class LiteralMatchNode(H) {
    long lexeme_index;
    LiteralMatchNode!(H)[char] tails;

    this(string str, long str_lexeme_index)
    {
        if (str.length == 0) {
            lexeme_index = str_lexeme_index;
        } else {
            lexeme_index = -1;
            tails[str[0]] = new LiteralMatchNode(str[1..$], str_lexeme_index);
        }
    }

    void add_tail(string new_tail, long nt_lexeme_index)
    {
        if (new_tail.length == 0) {
            if (lexeme_index >= 0) throw new LexanException("");
            lexeme_index = nt_lexeme_index;
        } else if (new_tail[0] in tails) {
            tails[new_tail[0]].add_tail(new_tail[1..$], nt_lexeme_index);
        } else {
            tails[new_tail[0]] = new LiteralMatchNode(new_tail[1..$], nt_lexeme_index);
        }
    }
}

class LiteralMatcher(H) {
private:
    LiteralLexeme!(H)[] lexemes;
    LiteralMatchNode!(H)[char] literals;

public:
    this(ref LiteralLexeme!(H)[] lexeme_list)
    {
        lexemes = lexeme_list;
        for (auto i = 0; i < lexemes.length; i++) {
            auto lexeme = lexemes[i];
            auto literal = lexeme.pattern;
            if (literal[0] in literals) {
                try {
                    literals[literal[0]].add_tail(literal[1..$], i);
                } catch (LexanException edata) {
                    throw new LexanDuplicateLiteralPattern(literal);
                }
            } else {
                literals[literal[0]] = new LiteralMatchNode!(H)(literal[1..$], i);
            }
        }
    }

    LiteralLexeme!(H) get_longest_match(string target)
    {
        LiteralLexeme!(H) lvm;
        auto lits = literals;
        for (auto index = 0; index < target.length && target[index] in lits; index++) {
            if (lits[target[index]].lexeme_index >= 0)
                lvm = lexemes[lits[target[index]].lexeme_index];
            lits = lits[target[index]].tails;
        }
        return lvm;
    }
}
unittest {
    import std.exception;
    auto test_strings = ["alpha", "beta", "gamma", "delta", "test", "tes", "tenth", "alpine", "gammon", "gamble"];
    LiteralLexeme!int[] test_lexemes;
    for (auto i = 0; i < test_strings.length; i++) {
        test_lexemes ~= LiteralLexeme!int(i, test_strings[i]);
    }
    auto rubbish = "garbage";
    auto lm = new LiteralMatcher!int(test_lexemes);
    foreach(test_string; test_strings) {
        assert(lm.get_longest_match(test_string).is_valid);
        assert(lm.get_longest_match(rubbish ~ test_string).is_valid == false);
        assert(lm.get_longest_match((rubbish ~ test_string)[rubbish.length..$]).is_valid == true);
        assert(lm.get_longest_match((rubbish ~ test_string ~ rubbish)[rubbish.length..$]).is_valid == true);
        assert(lm.get_longest_match(test_string ~ rubbish).is_valid == true);
    }
    foreach(test_string; test_strings) {
        assert(lm.get_longest_match(test_string).pattern == test_string);
        assert(lm.get_longest_match(rubbish ~ test_string).is_valid == false);
        assert(lm.get_longest_match((rubbish ~ test_string)[rubbish.length..$]).pattern == test_string);
        assert(lm.get_longest_match((rubbish ~ test_string ~ rubbish)[rubbish.length..$]).pattern == test_string);
        assert(lm.get_longest_match(test_string ~ rubbish).pattern == test_string);
    }
    auto bad_strings = test_strings ~ "gamma";
    LiteralLexeme!int[] bad_lexemes;
    for (auto i = 0; i < bad_strings.length; i++) {
        bad_lexemes ~= LiteralLexeme!int(i, bad_strings[i]);
    }
    try {
        auto bad_lm = new LiteralMatcher!int(bad_lexemes);
        assert(false, "should blow up before here!");
    } catch (LexanDuplicateLiteralPattern edata) {
        assert(edata.duplicate_pattern == "gamma");
    }
}

struct CharLocation {
    // Line numbers and offsets both start at 1 (i.e. human friendly)
    // as these are used for error messages.
    size_t index;
    size_t line_number;
    size_t offset;
    string label; // e.g. name of file that text came from

    const string toString()
    {
        if (label.length > 0) {
            return format("%s:%s(%s)", label, line_number, offset);
        } else {
            return format("%s(%s)", line_number, offset);
        }
    }
}

class Token(H) {
private:
    H _handle;
    string _matched_text;
    CharLocation _location;
    bool _is_valid_match;

public:
    this(H handle, string text, CharLocation locn)
    {
        _handle = handle;
        _matched_text = text;
        _location = locn;
        _is_valid_match = true;
    }

    this(string text, CharLocation locn)
    {
        _matched_text = text;
        _location = locn;
        _is_valid_match = false;
    }

    @property
    H handle()
    {
        if (!_is_valid_match) throw new LexanInvalidToken(_matched_text, location);
        return _handle;
    }

    @property
    ref string matched_text()
    {
        return _matched_text;
    }

    @property
    CharLocation location()
    {
        return _location;
    }

    @property
    bool is_valid_match()
    {
        return _is_valid_match;
    }
}

struct HandleAndText(H) {
    H handle;
    string text;

    @property
    size_t length()
    {
        return text.length;
    }

    @property
    bool is_valid()
    {
        return text.length > 0;
    }
}

interface LexicalAnalyserIfce(H) {
    size_t get_skippable_count(string text);
    LiteralLexeme!(H) get_longest_literal_match(string text);
    HandleAndText!(H)[] get_longest_regex_match(string text);
    size_t distance_to_next_valid_input(string text);
    TokenForwardRange!(H) token_forward_range(string text, string label);
    TokenForwardRange!(H) token_forward_range(string text, string label, H end_handle);
    InjectableTokenForwardRange!(H) injectable_token_forward_range(string text, string label);
    InjectableTokenForwardRange!(H) injectable_token_forward_range(string text, string label, H end_handle);
}

class LexicalAnalyser(H, RE): LexicalAnalyserIfce!(H) {
    private LiteralMatcher!(H) literal_matcher;
    private RegexLexeme!(H, RE)[] re_lexemes;
    private RE[] skip_re_list;

    this(ref LiteralLexeme!(H)[] lit_lexemes, ref RegexLexeme!(H, RE)[] re_lexemes, ref RE[] skip_re_list)
    in {
        // Make sure handles are unique
        for (auto i = 0; i < (lit_lexemes.length - 1); i++) {
            for (auto j = i + 1; j < lit_lexemes.length; j++) {
                assert(lit_lexemes[i].handle != lit_lexemes[j].handle);
            }
        }
        for (auto i = 0; i < (re_lexemes.length - 1); i++) {
            for (auto j = i + 1; j < re_lexemes.length; j++) {
                assert(re_lexemes[i].handle != re_lexemes[j].handle);
            }
        }
        for (auto i = 0; i < lit_lexemes.length; i++) {
            for (auto j = 0; j < re_lexemes.length; j++) {
                assert(lit_lexemes[i].handle != re_lexemes[j].handle);
            }
        }
    }
    body {
        literal_matcher = new LiteralMatcher!(H)(lit_lexemes);
        this.re_lexemes = re_lexemes;
        this.skip_re_list = skip_re_list;
    }

    size_t get_skippable_count(string text)
    {
        size_t index = 0;
        while (index < text.length) {
            auto skips = 0;
            foreach (skip_re; skip_re_list) {
                auto m = match(text[index..$], skip_re);
                if (!m.empty) {
                    index += m.hit.length;
                    skips++;
                }
            }
            if (skips == 0) break;
        }
        return index;
    }

    LiteralLexeme!(H) get_longest_literal_match(string text)
    {
        return literal_matcher.get_longest_match(text);
    }

    HandleAndText!(H)[] get_longest_regex_match(string text)
    {
        HandleAndText!(H)[] hat;

        foreach (re_lexeme; re_lexemes) {
            auto m = match(text, re_lexeme.re);
            // TODO: check for two or more of the same length
            // and throw a wobbly
            if (m) {
                if (hat.length == 0 || hat[0].length == m.hit.length) {
                    hat ~= HandleAndText!(H)(re_lexeme.handle, m.hit);
                } else if (m.hit.length > hat.length) {
                    hat = [HandleAndText!(H)(re_lexeme.handle, m.hit)];
                }
            }
        }

        return hat;
    }

    size_t distance_to_next_valid_input(string text)
    {
        size_t index = 0;
        mainloop: while (index < text.length) {
            // Assume that the front of the text is invalid
            // TODO: put in precondition to that effect
            index++;
            if (literal_matcher.get_longest_match(text[index..$]).is_valid) break;
            foreach (re_lexeme; re_lexemes) {
                if (match(text[index..$], re_lexeme.re)) break mainloop;
            }
            foreach (skip_re; skip_re_list) {
                if (match(text[index..$], skip_re)) break mainloop;
            }
        }
        return index;
    }

    TokenForwardRange!(H) token_forward_range(string text, string label)
    {
        return TokenForwardRange!(H)(this, text, label);
    }

    TokenForwardRange!(H) token_forward_range(string text, string label, H end_handle)
    {
        return TokenForwardRange!(H)(this, text, label, end_handle);
    }

    InjectableTokenForwardRange!(H) injectable_token_forward_range(string text, string label)
    {
        return InjectableTokenForwardRange!(H)(this, text, label);
    }

    InjectableTokenForwardRange!(H) injectable_token_forward_range(string text, string label, H end_handle)
    {
        return InjectableTokenForwardRange!(H)(this, text, label, end_handle);
    }
}

struct TokenForwardRange(H) {
    LexicalAnalyserIfce!(H) analyser;
    private string input_text;
    private CharLocation index_location;
    private Token!(H) current_match;
    private H end_handle;
    private bool send_end_of_input;

    this (LexicalAnalyserIfce!(H) analyser, string text, string label)
    {
        this.analyser = analyser;
        index_location = CharLocation(0, 1, 1, label);
        input_text = text;
        current_match = advance();
    }

    this (LexicalAnalyserIfce!(H) analyser, string text, string label, H end_handle)
    {
        this.end_handle = end_handle;
        this.send_end_of_input = true;
        this(analyser, text, label);
    }

    private void incr_index_location(size_t length)
    {
        auto next_index = index_location.index + length;
        for (auto i = index_location.index; i < next_index; i++) {
            static if (newline.length == 1) {
                if (newline[0] == input_text[i]) {
                    index_location.line_number++;
                    index_location.offset = 1;
                } else {
                    index_location.offset++;
                }
            } else {
                if (newline == input_text[i..i + newline.length]) {
                    index_location.line_number++;
                    index_location.offset = 0;
                } else {
                    index_location.offset++;
                }
            }
        }
        index_location.index = next_index;
    }

    private Token!(H) advance()
    {
        while (index_location.index < input_text.length) {
            // skips have highest priority
            incr_index_location(analyser.get_skippable_count(input_text[index_location.index..$]));
            if (index_location.index >= input_text.length) break;

            // The reported location is for the first character of the match
            auto location = index_location;

            // Find longest match found by literal match or regex
            auto llm = analyser.get_longest_literal_match(input_text[index_location.index..$]);

            auto lrem = analyser.get_longest_regex_match(input_text[index_location.index..$]);

            if (llm.is_valid && (lrem.length == 0 || llm.length >= lrem[0].length)) {
                // if the matches are of equal length literal wins
                incr_index_location(llm.length);
                return new Token!(H)(llm.handle, llm.pattern, location);
            } else if (lrem.length == 1) {
                incr_index_location(lrem[0].length);
                return new Token!(H)(lrem[0].handle, lrem[0].text, location);
            } else if (lrem.length > 1) {
                incr_index_location(lrem[0].length);
                throw new LexanMultipleRegexMatches!(H)(lrem, location);
            } else {
                // Failure: send back the offending character(s) and location
                auto start = index_location.index;
                incr_index_location(analyser.distance_to_next_valid_input(input_text[index_location.index..$]));
                return new Token!(H)(input_text[start..index_location.index], location);
            }
        }

        if (send_end_of_input) {
            send_end_of_input = false; // so we don't send multiple end tokens
            return new Token!(H)(end_handle, "", index_location);
        }
        return null;
    }

    @property
    bool empty()
    {
        return current_match is null;
    }

    @property
    Token!(H) front()
    {
        return current_match;
    }

    void popFront()
    {
        current_match = advance();
    }

    Token!(H) moveFront()
    {
        auto retval = current_match;
        current_match = advance();
        return retval;
    }

    TokenForwardRange!(H) save()
    {
        return this;
    }
}

unittest {
    import std.exception;
    auto lit_lexemes = [
        LiteralLexeme!string("IF", "if"),
        LiteralLexeme!string("WHEN", "when"),
    ];
    auto re_lexemes = [
        RegexLexeme!(string, Regex!char)("IDENT", regex("^[a-zA-Z]+[\\w_]*")),
        RegexLexeme!(string, Regex!char)("BTEXTL", regex(r"^&\{(.|[\n\r])*&\}")),
        RegexLexeme!(string, Regex!char)("PRED", regex(r"^\?\{(.|[\n\r])*\?\}")),
        RegexLexeme!(string, Regex!char)("LITERAL", regex("^(\"\\S+\")")),
        RegexLexeme!(string, Regex!char)("ACTION", regex(r"^(!\{(.|[\n\r])*?!\})")),
        RegexLexeme!(string, Regex!char)("PREDICATE", regex(r"^(\?\((.|[\n\r])*?\?\))")),
        RegexLexeme!(string, Regex!char)("CODE", regex(r"^(%\{(.|[\n\r])*?%\})")),
        RegexLexeme!(string, Regex!char)("MORSE", regex(r"^(%\{(.|[\n\r])*?%\})")),
    ];
    auto skip_re_list = [
        regex(r"^(/\*(.|[\n\r])*?\*/)"), // D multi line comment
        regex(r"^(//[^\n\r]*)"), // D EOL comment
        regex(r"^(\s+)"), // White space
    ];
    auto laspec = new LexicalAnalyser!(string, Regex!char)(lit_lexemes, re_lexemes, skip_re_list);
    auto la = laspec.token_forward_range("if iffy\n \"quoted\" \"if\" \n9 $ \tname &{ one \n two &} and so ?{on?}", "");
    auto m = la.front(); la.popFront();
    assert(m.handle == "IF" && m.matched_text == "if" && m.location.line_number == 1);
    m = la.front(); la.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "iffy" && m.location.line_number == 1);
    m = la.front(); la.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"quoted\"" && m.location.line_number == 2);
    m = la.front(); la.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"if\"" && m.location.line_number == 2);
    m = la.front(); la.popFront();
    assert(!m.is_valid_match && m.matched_text == "9" && m.location.line_number == 3);
    assertThrown!LexanInvalidToken(m.handle != "blah blah blah");
    m = la.front(); la.popFront();
    assert(!m.is_valid_match && m.matched_text == "$" && m.location.line_number == 3);
    m = la.front(); la.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "name" && m.location.line_number == 3);
    auto saved_la = la.save();
    m = la.front(); la.popFront();
    assert(m.handle == "BTEXTL" && m.matched_text == "&{ one \n two &}" && m.location.line_number == 3);
    m = la.front(); la.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "and" && m.location.line_number == 4);
    m = saved_la.moveFront();
    assert(m.handle == "BTEXTL" && m.matched_text == "&{ one \n two &}" && m.location.line_number == 3);
    m = saved_la.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "and" && m.location.line_number == 4);
    m = la.front(); la.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "so" && m.location.line_number == 4);
    m = la.front(); la.popFront();
    assert(m.handle == "PRED" && m.matched_text == "?{on?}" && m.location.line_number == 4);
    assert(la.empty);
    m = saved_la.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "so" && m.location.line_number == 4);
    m = saved_la.moveFront();
    assert(m.handle == "PRED" && m.matched_text == "?{on?}" && m.location.line_number == 4);
    assert(saved_la.empty);
    la = laspec.token_forward_range("
    some identifiers
// a single line comment with \"quote\"
some more identifiers.
/* a
multi line
comment */

\"+=\" and more ids.
\"\"\"
and an action !{ some D code !} and a predicate ?( a boolean expression ?)
and some included code %{
    kllkkkl
    hl;ll
%}
", "");
    m = la.front(); la.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "some" && m.location.line_number == 2);
    m = la.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "identifiers" && m.location.line_number == 2);
    m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront();
    assert(!m.is_valid_match);
    m = la.front(); la.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"+=\"" && m.location.line_number == 9);
    m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront();
    m = la.front(); la.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"\"\"" && m.location.line_number == 10);
    m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront();
    m = la.front(); la.popFront();
    assert(m.handle == "ACTION" && m.matched_text == "!{ some D code !}" && m.location.line_number == 11);
    m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront();
    m = la.front(); la.popFront();
    assert(m.handle == "PREDICATE" && m.matched_text == "?( a boolean expression ?)" && m.location.line_number == 11);
    try {
        m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront(); m = la.front(); la.popFront();
        m = la.front(); la.popFront();
        assert(m.handle == "CODE" && m.matched_text == "%{\n    kllkkkl\n    hl;ll\n%}" && m.location.line_number == 12);
        assert(false, "Blows up before here!");
    } catch (LexanMultipleRegexMatches!(string) edata) {
        assert(edata.handles == ["CODE", "MORSE"]);
    }
    auto ilit_lexemes = [
        LiteralLexeme!int(0, "if"),
        LiteralLexeme!int(8, "when"),
    ];
    auto ire_lexemes = [
        RegexLexeme!(int, Regex!char)(1, regex("^[a-zA-Z]+[\\w_]*")),
        RegexLexeme!(int, Regex!char)(2, regex(r"^&\{(.|[\n\r])*&\}")),
        RegexLexeme!(int, Regex!char)(3, regex(r"^\?\{(.|[\n\r])*\?\}")),
        RegexLexeme!(int, Regex!char)(4, regex("^(\"\\S+\")")),
        RegexLexeme!(int, Regex!char)(5, regex(r"^(!\{(.|[\n\r])*?!\})")),
        RegexLexeme!(int, Regex!char)(6, regex(r"^(\?\((.|[\n\r])*?\?\))")),
        RegexLexeme!(int, Regex!char)(7, regex(r"^(%\{(.|[\n\r])*?%\})")),
    ];
    auto ilaspec = new LexicalAnalyser!(int, Regex!char)(ilit_lexemes, ire_lexemes, skip_re_list);
    auto ila = ilaspec.token_forward_range("if iffy\n \"quoted\" $! %%name \"if\" \n9 $ \tname &{ one \n two &} and so ?{on?}", "");
    auto im = ila.front(); ila.popFront();
    assert(im.handle == 0 && im.matched_text == "if" && im.location.line_number == 1);
    im = ila.front(); ila.popFront();
    assert(im.handle == 1 && im.matched_text == "iffy" && im.location.line_number == 1);
    im = ila.front(); ila.popFront();
    assert(im.handle == 4 && im.matched_text == "\"quoted\"" && im.location.line_number == 2);
    im = ila.moveFront();
    assert(!im.is_valid_match && im.matched_text == "$!" && im.location.line_number == 2);
    im = ila.front(); ila.popFront();
    assert(!im.is_valid_match && im.matched_text == "%%" && im.location.line_number == 2);
}

struct InjectableTokenForwardRange(H) {
    LexicalAnalyserIfce!(H) analyser;
    TokenForwardRange!(H)[] token_range_stack;

    this (LexicalAnalyserIfce!(H) analyser, string text, string label)
    {
        this.analyser = analyser;
        token_range_stack ~= analyser.token_forward_range(text, label);
    }

    this (LexicalAnalyserIfce!(H) analyser, string text, string label, H end_handle)
    {
        this.analyser = analyser;
        token_range_stack ~= analyser.token_forward_range(text, label, end_handle);
    }

    void inject(string text, string label)
    {
        token_range_stack ~= analyser.token_forward_range(text, label);
    }

    @property
    bool empty()
    {
        return token_range_stack.length == 0;
    }

    @property
    Token!(H) front()
    {
        if (token_range_stack.length == 0) return null;
        return token_range_stack[$ - 1].current_match;
    }

    void popFront()
    {
        token_range_stack[$ - 1].popFront();
        while (token_range_stack.length > 0 && token_range_stack[$ - 1].empty) token_range_stack.length--;
    }

    Token!(H) moveFront()
    {
        auto retval = front;
        popFront();
        return retval;
    }

    InjectableTokenForwardRange!(H) save()
    {
        InjectableTokenForwardRange!(H) retval;
        retval.analyser = analyser;
        foreach (token_range; token_range_stack) {
            retval.token_range_stack ~= token_range.save();
        }
        return retval;
    }
}
unittest {
    auto lit_lexemes = [
        LiteralLexeme!string("IF", "if"),
        LiteralLexeme!string("WHEN", "when"),
    ];
    auto re_lexemes = [
        RegexLexeme!(string, Regex!char)("IDENT", regex("^[a-zA-Z]+[\\w_]*")),
        RegexLexeme!(string, Regex!char)("BTEXTL", regex(r"^&\{(.|[\n\r])*&\}")),
        RegexLexeme!(string, Regex!char)("PRED", regex(r"^\?\{(.|[\n\r])*\?\}")),
        RegexLexeme!(string, Regex!char)("LITERAL", regex("^(\"\\S+\")")),
        RegexLexeme!(string, Regex!char)("ACTION", regex(r"^(!\{(.|[\n\r])*?!\})")),
        RegexLexeme!(string, Regex!char)("PREDICATE", regex(r"^(\?\((.|[\n\r])*?\?\))")),
        RegexLexeme!(string, Regex!char)("CODE", regex(r"^(%\{(.|[\n\r])*?%\})")),
    ];
    auto skip_re_list = [
        regex(r"^(/\*(.|[\n\r])*?\*/)"), // D multi line comment
        regex(r"^(//[^\n\r]*)"), // D EOL comment
        regex(r"^(\s+)"), // White space
    ];
    auto laspec = new LexicalAnalyser!(string, Regex!char)(lit_lexemes, re_lexemes, skip_re_list);
    auto ila = laspec.injectable_token_forward_range("if iffy\n \"quoted\" \"if\" \n9 $ \tname &{ one \n two &} and so ?{on?}", "one");
    auto m = ila.front(); ila.popFront();
    assert(m.handle == "IF" && m.matched_text == "if" && m.location.line_number == 1);
    m = ila.front(); ila.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "iffy" && m.location.line_number == 1);
    m = ila.front(); ila.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"quoted\"" && m.location.line_number == 2);
    m = ila.moveFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"if\"" && m.location.line_number == 2);
    m = ila.front(); ila.popFront();
    assert(!m.is_valid_match && m.matched_text == "9" && m.location.line_number == 3);
    ila.inject("if one \"name\"", "two");
    m = ila.front(); ila.popFront();
    assert(m.handle == "IF" && m.matched_text == "if" && m.location.line_number == 1 && m.location.label == "two");
    auto saved_ila = ila.save();
    m = ila.front(); ila.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "one" && m.location.line_number == 1 && m.location.label == "two");
    m = ila.front(); ila.popFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"name\"" && m.location.line_number == 1 && m.location.label == "two");
    m = ila.front(); ila.popFront();
    assert(!m.is_valid_match && m.matched_text == "$" && m.location.line_number == 3);
    m = ila.front(); ila.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "name" && m.location.line_number == 3);
    m = saved_ila.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "one" && m.location.line_number == 1 && m.location.label == "two");
    m = saved_ila.moveFront();
    assert(m.handle == "LITERAL" && m.matched_text == "\"name\"" && m.location.line_number == 1 && m.location.label == "two");
    m = saved_ila.moveFront();
    assert(!m.is_valid_match && m.matched_text == "$" && m.location.line_number == 3);
    m = saved_ila.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "name" && m.location.line_number == 3);
    m = ila.front(); ila.popFront();
    assert(m.handle == "BTEXTL" && m.matched_text == "&{ one \n two &}" && m.location.line_number == 3);
    m = ila.front(); ila.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "and" && m.location.line_number == 4);
    m = ila.front(); ila.popFront();
    assert(m.handle == "IDENT" && m.matched_text == "so" && m.location.line_number == 4);
    m = ila.front(); ila.popFront();
    assert(m.handle == "PRED" && m.matched_text == "?{on?}" && m.location.line_number == 4);
    assert(ila.empty);
    m = saved_ila.moveFront();
    assert(m.handle == "BTEXTL" && m.matched_text == "&{ one \n two &}" && m.location.line_number == 3);
    m = saved_ila.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "and" && m.location.line_number == 4);
    m = saved_ila.moveFront();
    assert(m.handle == "IDENT" && m.matched_text == "so" && m.location.line_number == 4);
    m = saved_ila.moveFront();
    assert(m.handle == "PRED" && m.matched_text == "?{on?}" && m.location.line_number == 4);
    assert(saved_ila.empty);
}
