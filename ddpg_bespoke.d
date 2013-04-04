#!/usr/bin/rdmd
import std.stdio;
import std.getopt;
import std.file;
import std.utf;

import generated;
import grammar;

bool verbose;

int main(string[] args)
{
    getopt(args, "v|verbose", &verbose);
    if (args.length != 2) {
        print_usage(args[0]);
        return -1;
    }
    // Read the text to be parsed
    auto inputFilePath = args[1];
    string inputText;
    try {
        inputText = readText(inputFilePath);
    } catch (FileException e) {
        writeln(e.errno);
        return 1;
    } catch (UTFException e) {
        writeln(e);
        return 2;
    }
    // Parse the text and generate the grammar specification
    auto parser = new DDParser;
    if (!parser.parse_text(inputText)) {
        return 3;
    }
    if (verbose) {
        writeln("Tokens:");
        foreach (token; symbolTable.get_tokens_ordered()) {
            with (token) {
                writefln("\t%s: %s: %s: %s: %s: %s: %s", id, name, type, pattern, fieldName, associativity, precedence);
                writefln("\t\tDefined At: %s", definedAt);
                writefln("\t\tUsed At: %s", usedAt);
            }
        }
        writeln("Not Terminals:");
        foreach (token; symbolTable.get_non_terminals_ordered()) {
            with (token) {
                writefln("\t%s: %s:", id, name);
                writefln("\t\tDefined At: %s", definedAt);
                writefln("\t\tUsed At: %s", usedAt);
            }
        }
        writeln("Productions:");
        for (auto i = 0; i < grammarSpecification.productionList.length; i++) {
            writefln("\t%s:\t%s", i, grammarSpecification.productionList[i]);
        }
    }
    // Generate the grammar from the specification
    auto grammar = new Grammar(grammarSpecification);
    if (grammar is null || !grammar.is_valid) {
        return 4;
    }
    if (verbose) {
        writeln("\nGrammar");
        writeln(grammar.get_parser_states_description());
    }
    return 0;
}

void print_usage(string command)
{
    writefln("Usage: [--verbose|-v] %s <file>", command);
}
