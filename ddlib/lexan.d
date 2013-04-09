// lexan.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module ddlib.lexan;

import std.regex;
import std.ascii;
import std.string;
// TODO: make sure LexicalAnalyser works with UTF-8 Unicode

enum MatchType {literal, regularExpression};

class TokenSpec {
    immutable string name;
    immutable MatchType matchType;
    union {
        immutable string pattern;
        Regex!(char) re;
    }

    this(string nm, string specdef)
    {
        name = nm;
        if (specdef[0] == '"' && specdef[$ - 1] == '"') {
            matchType = MatchType.literal;
            pattern = specdef[1 .. $ - 1];
        } else {
            matchType = MatchType.regularExpression;
            re =  regex("^" ~ specdef);
        }
    }
}

unittest {
    auto ts = new TokenSpec("TEST", "\"test\"");
    assert(ts.name == "TEST");
    assert(ts.matchType == MatchType.literal);
    assert(ts.pattern == "test");
    ts = new TokenSpec("TESTRE", "[a-zA-Z]+");
    assert(ts.name == "TESTRE");
    assert(ts.matchType == MatchType.regularExpression);
    assert(!ts.re.empty);
}

class LiteralMatchNode {
    bool validMatch;
    LiteralMatchNode[char] tails;

    this(string str)
    {
        validMatch = str.length == 0;
        if (!validMatch) {
            tails[str[0]] = new LiteralMatchNode(str[1 .. $]);
        }
    }

    void add_tail(string new_tail)
    {
        if (new_tail.length == 0) {
            validMatch = true;
        } else if (new_tail[0] in tails) {
            tails[new_tail[0]].add_tail(new_tail[1 .. $]);
        } else {
            tails[new_tail[0]] = new LiteralMatchNode(new_tail[1 .. $]);
        }
    }
}

class LiteralMatcher {
private:
    LiteralMatchNode[char] literals;

public:
    void add_literal(string literal)
    {
        if (literal[0] in literals) {
            literals[literal[0]].add_tail(literal[1 .. $]);
        } else {
            literals[literal[0]] = new LiteralMatchNode(literal[1 .. $]);
        }
    }

    string get_longest_match(string target, size_t offset=0)
    {
        auto lvm = offset;
        auto lits = literals;
        for (auto index = offset; index < target.length && target[index] in lits; index++) {
            if (lits[target[index]].validMatch)
                lvm = index + 1;
            lits = lits[target[index]].tails;
        }
        return target[offset .. lvm];
    }
}

unittest {
    auto lm = new LiteralMatcher;
    auto test_strings = ["alpha", "beta", "gamma", "delta", "test", "tes", "tenth"];
    auto rubbish = "rubbish";
    foreach(test_string; test_strings) {
        assert(lm.get_longest_match(rubbish ~ test_string) == "");
        assert(lm.get_longest_match(rubbish ~ test_string, rubbish.length) == "");
        assert(lm.get_longest_match(rubbish ~ test_string ~ rubbish, rubbish.length) == "");
        assert(lm.get_longest_match(test_string ~ rubbish) == "");
    }
    foreach(test_string; test_strings) {
        lm.add_literal(test_string);
    }
    foreach(test_string; test_strings) {
        assert(lm.get_longest_match(test_string) == test_string);
    }
    foreach(test_string; test_strings ~ []) {
        assert(lm.get_longest_match(rubbish ~ test_string) == "");
        assert(lm.get_longest_match(rubbish ~ test_string, rubbish.length) == test_string);
        assert(lm.get_longest_match(rubbish ~ test_string ~ rubbish, rubbish.length) == test_string);
        assert(lm.get_longest_match(test_string ~ rubbish) == test_string);
    }
}

struct CharLocation {
    // Line numbers and offsets both start at 1 (i.e. human friendly)
    // as these are used for error messages.
    size_t lineNumber;
    size_t offset;
    string label; // e.g. name of file that text came from

    const string toString()
    {
        if (label.length > 0) {
            return format("%s:%s(%s)", label, lineNumber, offset);
        } else {
            return format("%s(%s)", lineNumber, offset);
        }
    }
}

class CharLocationData {
    private size_t[] lineStart;
    string label;

    this(string text, string label="")
    {
        this.label = label;
        lineStart = [0];
        if (newline.length == 1) {
            for (size_t i; i < text.length; i++)
                if (newline[0] == text[i])
                    lineStart ~= (i + 1);
        } else {
            for (size_t i; i < text.length - newline.length + 1; i++)
                if (newline == text[i .. i + newline.length])
                    lineStart ~= (i + newline.length);
        }
    }

    CharLocation get_char_location(size_t index)
    {
        size_t imin = 0;
        size_t imax = lineStart.length - 1;

        while (imax > imin) {
            size_t imid = (imin + imax) / 2;
            if (lineStart[imid] < index) {
                imin = imid + 1;
            } else {
                imax = imid;
            }
        }
        // lineStart.length > 0 so this should hold?
        assert(imin == imax);

        // index will be on line at lineStart[imin] or the one before
        auto ln = (index < lineStart[imin]) ? imin : imin + 1;
        auto offset = index - lineStart[ln - 1] + 1;

        return CharLocation(ln, offset, label);
    }
}

class MatchResult {
    TokenSpec tokenSpec;
    string matchedText;
    CharLocation location;

    this(TokenSpec spec, string text, CharLocation locn)
    {
        tokenSpec = spec;
        matchedText = text;
        location = locn;
    }

    this(string text, CharLocation locn)
    {
        tokenSpec = null;
        matchedText = text;
        location = locn;
    }

    @property
    bool is_valid_token()
    {
        return tokenSpec !is null;
    }
}

// TODO: add a mechanism for enabling/disabling TokenSpecs at runtime
class LexicalAnalyser {
    private LiteralMatcher literalMatcher;
    private TokenSpec[] bracketedTokenSpecs;
    private TokenSpec[string] literalTokenSpecs;
    private TokenSpec[] regexTokenSpecs;
    private string inputText;
    private size_t index;
    private CharLocationData charLocationData;
    private Regex!(char)[] skipReList;

    this(TokenSpec[] tokenSpecs, string[] skipPatterns = [])
    {
        literalMatcher = new LiteralMatcher;
        auto lcnt = 0;
        auto recnt = 0;
        foreach (ts; tokenSpecs) {
            if (ts.matchType == MatchType.literal) {
                literalTokenSpecs[ts.pattern] = ts;
                literalMatcher.add_literal(ts.pattern);
                lcnt++;
            } else if (ts.matchType == MatchType.regularExpression) {
                regexTokenSpecs ~= ts;
                recnt++;
            }
        }
        foreach (skipPat; skipPatterns) {
            skipReList ~= regex("^" ~ skipPat);
        }
        assert(lcnt == literalTokenSpecs.length);
        assert(recnt == regexTokenSpecs.length);
    }

    void set_input_text(string text, string label="")
    {
        inputText = text;
        index = 0;
        charLocationData = new CharLocationData(text, label);
    }

    MatchResult advance()
    {
        mainloop: while (index < inputText.length) {
            // skips have highest priority
            foreach (skipRe; skipReList) {
                auto m = match(inputText[index .. $], skipRe);
                if (!m.empty) {
                    index += m.hit.length;
                    continue mainloop;
                }
            }

            // The reported location is for the first character of the match
            auto location = charLocationData.get_char_location(index);

            // Find longest match found by literal match or regex
            auto llm = literalMatcher.get_longest_match(inputText, index);

            auto lrem = "";
            TokenSpec lremts;
            foreach (tspec; regexTokenSpecs) {
                auto m = match(inputText[index .. $], tspec.re);
                if (m && m.hit.length > lrem.length) {
                    lrem = m.hit;
                    lremts = tspec;
                }
            }

            if (llm.length && llm.length >= lrem.length) {
                // if the matches are of equal length literal wins
                index += llm.length;
                return new MatchResult(literalTokenSpecs[llm], llm, location);
            } else if (lrem.length) {
                index += lrem.length;
                return new MatchResult(lremts, lrem, location);
            } else {
                // Failure: send back the offending character and its location
                index += 1;
                return new MatchResult(inputText[index - 1 .. index], location);
            }
        }

        return null;
    }
}

unittest {
    TokenSpec[] tslist = [
        new TokenSpec("IF", "\"if\""),
        new TokenSpec("IDENT", "[a-zA-Z]+[\\w_]*"),
        new TokenSpec("BTEXTL", r"&\{(.|[\n\r])*&\}"),
        new TokenSpec("PRED", r"\?\{(.|[\n\r])*\?\}"),
        new TokenSpec("LITERAL", "(\"\\S+\")"),
        new TokenSpec("ACTION", r"(!\{(.|[\n\r])*?!\})"),
        new TokenSpec("PREDICATE", r"(\?\((.|[\n\r])*?\?\))"),
        new TokenSpec("CODE", r"(%\{(.|[\n\r])*?%\})"),
    ];
    string[] skiplist = [
        r"(/\*(.|[\n\r])*?\*/)", // D multi line comment
        r"(//[^\n\r]*)", // D EOL comment
        r"(\s+)", // White space
    ];
    auto la = new LexicalAnalyser(tslist, skiplist);
    la.set_input_text("if iffy\n \"quoted\" \"if\" \n9 $ \tname &{ one \n two &} and so ?{on?}");
    MatchResult m = la.advance();
    assert(m.tokenSpec.name == "IF" && m.matchedText == "if" && m.location.lineNumber == 1);
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "iffy" && m.location.lineNumber == 1);
    m = la.advance();
    assert(m.tokenSpec.name == "LITERAL" && m.matchedText == "\"quoted\"" && m.location.lineNumber == 2);
    m = la.advance();
    assert(m.tokenSpec.name == "LITERAL" && m.matchedText == "\"if\"" && m.location.lineNumber == 2);
    m = la.advance();
    assert(m.tokenSpec is null && m.matchedText == "9" && m.location.lineNumber == 3);
    m = la.advance();
    assert(m.tokenSpec is null && m.matchedText == "$" && m.location.lineNumber == 3);
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "name" && m.location.lineNumber == 3);
    m = la.advance();
    assert(m.tokenSpec.name == "BTEXTL" && m.matchedText == "&{ one \n two &}" && m.location.lineNumber == 3);
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "and" && m.location.lineNumber == 4);
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "so" && m.location.lineNumber == 4);
    m = la.advance();
    assert(m.tokenSpec.name == "PRED" && m.matchedText == "?{on?}" && m.location.lineNumber == 4);
    assert(la.advance() is null);
    la.set_input_text("
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
");
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "some" && m.location.lineNumber == 2);
    m = la.advance();
    assert(m.tokenSpec.name == "IDENT" && m.matchedText == "identifiers" && m.location.lineNumber == 2);
    m = la.advance(); m = la.advance(); m = la.advance(); m = la.advance();
    assert(m.tokenSpec is null);
    m = la.advance();
    assert(m.tokenSpec.name == "LITERAL" && m.matchedText == "\"+=\"" && m.location.lineNumber == 9);
    m = la.advance(); m = la.advance(); m = la.advance(); m = la.advance();
    m = la.advance();
    assert(m.tokenSpec.name == "LITERAL" && m.matchedText == "\"\"\"" && m.location.lineNumber == 10);
    m = la.advance(); m = la.advance(); m = la.advance();
    m = la.advance();
    assert(m.tokenSpec.name == "ACTION" && m.matchedText == "!{ some D code !}" && m.location.lineNumber == 11);
    m = la.advance(); m = la.advance(); m = la.advance();
    m = la.advance();
    assert(m.tokenSpec.name == "PREDICATE" && m.matchedText == "?( a boolean expression ?)" && m.location.lineNumber == 11);
    m = la.advance(); m = la.advance(); m = la.advance(); m = la.advance();
    m = la.advance();
    assert(m.tokenSpec.name == "CODE" && m.matchedText == "%{\n    kllkkkl\n    hl;ll\n%}" && m.location.lineNumber == 12);
}
