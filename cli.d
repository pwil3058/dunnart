// cli.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module cli;

import std.stdio;
import std.file;
import std.getopt;
import std.regex;
import std.path;

bool verbose;
bool force;
string moduleName;
string inputFilePath;
string outputFilePath;
string prefixPath;
uint expectedNumberOfConflicts;

bool process_command_line(string[] args)
{
    getopt(args,
        "f|force", &force,
        "m|module", &moduleName,
        "v|verbose", &verbose,
        "o|output", &outputFilePath,
        "p|prefix", &prefixPath,
        "e|expect", &expectedNumberOfConflicts,
    );
    if (args.length != 2) {
        print_usage(args[0]);
        return false;
    }
    inputFilePath = args[1];

    // if the output file path isn't specified then generate it
    if (outputFilePath.length == 0) {
        if (moduleName.length > 0) {
            outputFilePath = module_file_path(moduleName, prefixPath);
            if (!isValidPath(outputFilePath)) {
                stderr.writefln("%s: is not a valid file path", outputFilePath);
                return false;
            }
        } else {
            outputFilePath = stripExtension(inputFilePath) ~ ".d";
        }
    }
    // Don't overwrite existing files without specific authorization
    if (!force && exists(outputFilePath)) {
        stderr.writefln("%s: already exists: use --force (or -f) to overwrite", outputFilePath);
        return false;
    }
    return true;
}

void print_usage(string command)
{
    writefln("Usage: %s [--force|-f] [--verbose|-v] [(--module|-m)=<module name>] [(--expect|-e)=<number>] [(--output|-0)=<output file name>] <input file>", command);
}

string module_file_path(string moduleName, string prefixPath)
{
    static auto split_re = regex(r"\.");
    string[] parts;
    if (prefixPath.length == 0) {
        return buildPath(split(moduleName, split_re)) ~ ".d";
    } else {
        return buildNormalizedPath([prefixPath] ~ split(moduleName, split_re)) ~ ".d";
    }
}
