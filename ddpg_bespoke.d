#!/usr/bin/rdmd
// ddpg_bespoke.d
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

import generated;
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
        writeln(e.errno);
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
    // Generate the grammar from the specification
    auto grammar = new Grammar(grammarSpecification);
    if (grammar is null || !grammar.is_valid) {
        return 5;
    }
    if (verbose) {
        writeln("\nGrammar");
        writeln(grammar.get_parser_states_description());
    }
    try {
        auto outputFile = File(outputFilePath, "w");
        grammar.write_parser_code(outputFile, moduleName);
    } catch (Exception e) {
        writeln(e);
        return 6;
    }
    return 0;
}
