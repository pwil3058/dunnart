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
string module_name;
string input_file_path;
string output_file_path;
string state_file_path;
string prefix_path;
uint expected_number_of_conflicts;

bool process_command_line(string[] args)
{
    getopt(args,
        "f|force", &force,
        "m|module", &module_name,
        "v|verbose", &verbose,
        "o|output", &output_file_path,
        "p|prefix", &prefix_path,
        "e|expect", &expected_number_of_conflicts,
        "s|states", &state_file_path,
    );
    if (args.length != 2) {
        print_usage(args[0]);
        return false;
    }
    input_file_path = args[1];

    // if the output file path isn't specified then generate it
    if (output_file_path.length == 0) {
        if (module_name.length > 0) {
            output_file_path = module_file_path(module_name, prefix_path);
            if (!isValidPath(output_file_path)) {
                stderr.writefln("%s: is not a valid file path", output_file_path);
                return false;
            }
        } else {
            output_file_path = stripExtension(input_file_path) ~ ".d";
        }
    }
    // Don't overwrite existing files without specific authorization
    if (!force && exists(output_file_path)) {
        stderr.writefln("%s: already exists: use --force (or -f) to overwrite", output_file_path);
        return false;
    }
    return true;
}

void print_usage(string command)
{
    writefln("Usage: %s [--force|-f] [--verbose|-v] [(--module|-m)=<module name>] [(--expect|-e)=<number>] [(--output|-0)=<output file name>] <input file>", command);
}

string module_file_path(string module_name, string prefix_path)
{
    static auto split_re = regex(r"\.");
    string[] parts;
    if (prefix_path.length == 0) {
        return buildPath(split(module_name, split_re)) ~ ".d";
    } else {
        return buildNormalizedPath([prefix_path] ~ split(module_name, split_re)) ~ ".d";
    }
}
