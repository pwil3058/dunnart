// workarounds.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

mixin template WorkAroundClassLimitations(T) {
    static if (is(T == class)) {
        // WORKAROUND: problems with const classes (e.g. opCmp signature)
        auto WACL_ECAST = (const T x) => cast(T)x;
        auto WACL_ACAST = (const T[] x) => cast(T[])x;
    } else {
        auto WACL_ECAST = (const T x) => x;
        auto WACL_ACAST = (const T[] x) => x;
    }
}
