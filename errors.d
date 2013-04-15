// errors.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Make exception's messages usable for error messages

import std.string;
import std.file;

string extract_file_exception_msg(FileException e)
{
    auto firstLine = splitLines(format("%s", e))[0];
    return firstLine[indexOf(firstLine, ": ") + 2 .. $];
}
