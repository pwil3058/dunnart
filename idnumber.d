// idnumber.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module idnumber;

mixin template IdNumber(T) {
    const T id;

    override hash_t toHash()
    {
        return id;
    }

    override bool opEquals(Object o)
    {
        return id == (cast(typeof(this)) o).id;
    }

    override int opCmp(Object o)
    {
        return id - (cast(typeof(this)) o).id;
    }
}

mixin template UniqueId(T) {
    mixin IdNumber!(T);
    protected static T next_id;

    const string set_unique_id = "id = next_id++;";
}
