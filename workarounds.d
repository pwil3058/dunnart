// workarounds.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.algorithm: find, sort;

mixin template WorkAroundClassCmpLimitations(T) {
    static if (is(T == class)) {
        // WORKAROUND: comparison problems with const classes
        auto WA_CMP_ECAST = (const T x) => cast(T)x;
    } else {
        auto WA_CMP_ECAST = (const T x) => x;
    }
}

// Does this list contain the item? For use in contracts.
private bool contains(T)(in T[] list, in T item)
{
    auto tail = find(list, item);
    return tail.length && tail[0] == item;
}
unittest {
    assert(contains([1, 3, 9, 12], 3));
    assert(!contains([1, 3, 9, 12], 5));
}

private bool is_ordered(T)(in T[] list)
{
    for (auto j = 1; j < list.length; j++) {
        static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
            if (cast(T) list[j - 1] > cast(T) list[j]) return false;
        } else {
            if (list[j - 1] > list[j]) return false;
        }
    }
    return true;
}
unittest {
    assert(is_ordered(new int[0]));
    assert(is_ordered([1]));
    assert(is_ordered([1, 1]));
    assert(is_ordered([1, 2, 3, 4, 5, 6, 7]));
    assert(!is_ordered([1, 2, 4, 3, 5, 6, 7]));
    assert(is_ordered([1, 2, 3, 5, 5, 6, 7]));
}

T[] wa_sort(T)(T[] list)
out (result) {
    assert(list.length == result.length);
    assert(result.is_ordered);
    foreach (item; list) assert(result.contains(item));
    foreach (item; result) assert(list.contains(item));
}
body {
    auto olist = new T[list.length];
    auto sr = sort(list);
    for (size_t index = 0; index < list.length; index++) {
        olist[index] = sr[index];
    }
    return olist;
}
