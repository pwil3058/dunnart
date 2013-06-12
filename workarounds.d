// workarounds.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

mixin template WorkAroundClassCmpLimitations(T) {
    static if (is(T == class)) {
        // WORKAROUND: comparison problems with const classes
        auto WA_CMP_ECAST = (const T x) => cast(T)x;
    } else {
        auto WA_CMP_ECAST = (const T x) => x;
    }
}
