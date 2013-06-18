#!/usr/bin/rdmd
// calc.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.file;

import parser;

int main(string[] args)
{
    auto text = readText(args[1]);
    writeln(text);
    dd_parse_text(text);

    return 0;
}
