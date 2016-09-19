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
import errors;

int main(string[] args)
{
    if (!process_command_line(args)) {
        return 1;
    }
    // Read the text to be parsed
    string input_text;
    try {
        input_text = readText(input_file_path);
    } catch (FileException e) {
        auto msg = extract_file_exception_msg(e);
        writeln(msg);
        return 2;
    } catch (UTFException e) {
        writefln("%s: not a valid text file: %s", input_file_path, e);
        return 3;
    }
    // Parse the text and generate the grammar specification
    auto grammar_specification = parse_specification_text(input_text, input_file_path);
    if (grammar_specification is null) return 4;
    if (verbose) {
        writeln("Grammar Specification\n");
        foreach (text_line; grammar_specification.get_description()) {
            writeln(text_line);
        }
    }
    // warn about unused symbols
    foreach (unused_symbol; grammar_specification.symbol_table.get_unused_symbols()) {
        warning(unused_symbol.defined_at, "Symbol \"%s\" is not used", unused_symbol);
    }
    // undefined symbols are fatal errors
    foreach (undefined_symbol; grammar_specification.symbol_table.get_undefined_symbols()) {
        foreach (locn; undefined_symbol.used_at) {
            error(locn, "Symbol \"%s\" is not defined", undefined_symbol);
        }
    }
    if (error_count > 0) {
        stderr.writefln("Too many (%s) errors aborting", error_count);
        return 5;
    }
    // Generate the grammar from the specification
    auto grammar = new Grammar(grammar_specification);
    if (grammar is null)  return 6;
    if (state_file_path) {
        try {
            auto state_file = File(state_file_path, "w");
            state_file.write(grammar.get_parser_states_description());
        } catch (Exception e) {
            writeln(e);
        }
    } else if (verbose) {
        writeln("\nGrammar");
        writeln(grammar.get_parser_states_description());
    }
    if (grammar.total_unresolved_conflicts > 0) {
        foreach (parser_state; grammar.parser_states) {
            foreach (src; parser_state.shift_reduce_conflicts) {
                writefln("State<%s>: shift/reduce conflict on token: %s", parser_state.id, src.shift_symbol);
            }
            foreach (rrc; parser_state.reduce_reduce_conflicts) {
                writefln("State<%s>: reduce/reduce conflict on token(s): %s", parser_state.id, rrc.look_ahead_set_intersection);
            }
        }
        if (grammar.total_unresolved_conflicts != expected_number_of_conflicts) {
            stderr.writefln("Unexpected conflicts (%s) aborting", grammar.total_unresolved_conflicts);
            return 7;
        }
    }
    try {
        auto output_file = File(output_file_path, "w");
        grammar.write_parser_code(output_file, module_name);
    } catch (Exception e) {
        writeln(e);
        return 8;
    }
    return 0;
}
