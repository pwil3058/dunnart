#!/usr/bin/rdmd
// ddpg.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.getopt;
import std.file;
import std.utf;

version (bootstrap) {
    import bootstrap;
} else {
    import dunnart;
}
import grammar;
import cli;

int main(string[] args)
{
    if (!process_command_line(args)) {
        return 1;
    }

    // Read the text to be parsed
    string inputText;
    try {
        inputText = readText(inputFilePath);
    } catch (FileException e) {
        writeln(e);
        return 2;
    } catch (UTFException e) {
        writeln(e);
        return 3;
    }
    // Parse the text and generate the grammar specification
    auto parser = new DDParser;
    if (!parser.parse_text(inputText)) {
        return 4;
    }
    if (verbose) {
        writeln("Grammar Specification\n");
        foreach (textLine; grammarSpecification.get_description()) {
            writeln(textLine);
        }
    }
    // warn about unused symbols
    foreach (unusedSymbol; grammarSpecification.symbolTable.get_unused_symbols()) {
        warning(unusedSymbol.definedAt, "Symbol \"%s\" is not used", unusedSymbol);
    }
    // undefined symbols are fatal errors
    foreach (undefinedSymbol; grammarSpecification.symbolTable.get_undefined_symbols()) {
        foreach (locn; undefinedSymbol.usedAt) {
            error(locn, "Symbol \"%s\" is not defined", undefinedSymbol);
        }
    }
    if (errorCount > 0) {
        stderr.writefln("Too many (%s) errors aborting", errorCount);
        return 5;
    }
    // Generate the grammar from the specification
    auto grammar = new Grammar(grammarSpecification);
    if (grammar is null) {
        return 6;
    }
    if (verbose) {
        writeln("\nGrammar");
        writeln(grammar.get_parser_states_description());
    }
    if (!grammar.is_valid) {
        for (auto i = 0; i < grammar.parserStates.length; i++) {
            with (grammar.parserStates[i]) {
                foreach (src; shiftReduceConflicts) {
                    stderr.writefln("State<%s>: shift/reduce conflict on token: %s", i, src.shiftSymbol);
                }
                foreach (rrc; reduceReduceConflicts) {
                    stderr.writefln("State<%s>: reduce/reduce conflict on token(s): %s", i, rrc.lookAheadSetIntersection);
                }
            }
        }
        stderr.writefln("Too many (%s) conflicts aborting", grammar.unresolvedRRConflicts + grammar.unresolvedSRConflicts);
        return 7;
    }
    try {
        auto outputFile = File(outputFilePath, "w");
        grammar.write_parser_code(outputFile, moduleName);
    } catch (Exception e) {
        writeln(e);
        return 8;
    }
    return 0;
}