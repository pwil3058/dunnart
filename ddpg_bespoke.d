#!/usr/bin/rdmd
import std.stdio;
import std.getopt;
import std.file;
import std.utf;

import generated;
import grammar;

int main(string[] args)
{
    getopt(args);
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
    // Generate the grammar from the specification
    auto grammar = new Grammar(grammarSpecification);
    if (!grammar.is_valid) {
        return 4;
    }
    return 0;
}

void print_usage(string command)
{
    writefln("Usage: %s <file>", command);
}
