// sets.d
//
// Copyright Peter Williams 2013 <pwil3058@bigpond.net.au>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module sets;

import std.string;
import std.algorithm;
import std.array;
import std.range;

import workarounds;

mixin template WorkAroundConstLimitations(T) {
    import std.traits: isAssignable;
    static if (!isAssignable!(T, const(T))) {
        // WORKAROUND: problems with const classes (e.g. opCmp signature)
        auto WA_ASSIGN_ECAST = (const T x) => cast(T)x;
        auto WA_ASSIGN_ACAST = (const T[] x) => cast(T[])x;
    } else {
        auto WA_ASSIGN_ECAST = (const T x) => x;
        auto WA_ASSIGN_ACAST = (const T[] x) => x;
    }
}

struct Set(T) {
    protected T[] _elements;
    invariant () {
        assert(is_ordered_no_dups(_elements));
    }

    this(in T[] initialElements...)
    out {
        assert(cardinality <= initialElements.length);
        assert(contains(initialElements));
    }
    body {
        mixin WorkAroundConstLimitations!T;
        _elements = WA_ASSIGN_ACAST(initialElements).dup.sort.remove_adj_dups();
    }

    @property
    size_t cardinality() const
    {
        return _elements.length;
    }

    int opApply(int delegate(T) dg)
    {
        foreach (element; _elements) {
            auto result = dg(element);
            if (result) return result;
        }
        return 0;
    }

    @property
    T[] elements() const
    out (result) {
        assert(result == _elements);
    }
    body {
        mixin WorkAroundConstLimitations!T;
        return  WA_ASSIGN_ACAST(_elements).dup;
    }

    Set clone() const
    out (result) {
        assert(distinct_element_arrays(result, this));
        assert(result == this);
    }
    body {
        mixin WorkAroundConstLimitations!T;
        auto cloneSet = Set();
        cloneSet._elements = WA_ASSIGN_ACAST(_elements).dup;
        return cloneSet;
    }

    void add(in T[] newElements...)
    out {
        assert(contains(newElements));
    }
    body {
        foreach(newElement; newElements) {
            this += newElement;
        }
    }

    ref Set opOpAssign(string op)(in Set otherSet) if (op == "|" || op == "-" || op == "^" || op == "&")
    // TODO: add contract to opOpAssign
    body {
        _elements = (mixin("this " ~ op ~ " otherSet"))._elements;
        return this;
    }

    ref Set opOpAssign(string op)(in T newElement) if (op == "+")
    out {
        assert(newElement in this);
    }
    body {
        mixin WorkAroundConstLimitations!T;
        auto result = binary_search(_elements, newElement);
        if (!result.found) {
            _elements ~= WA_ASSIGN_ECAST(newElement);
            if (_elements.length > 1 && result.index < _elements.length - 1) {
                copy(retro(_elements[result.index .. $ - 1]), retro(_elements[result.index + 1 .. $]));
                _elements[result.index] = WA_ASSIGN_ECAST(newElement);
            }
        }
        return this;
    }

    void remove(in T[] delElements...)
    out {
        foreach (delElement; delElements) assert(delElement !in this);
    }
    body {
        foreach(delElement; delElements) {
            this -= delElement;
        }
    }

    ref Set opOpAssign(string op)(in T delElement) if (op == "-")
    out {
        assert(delElement !in this);
    }
    body {
        auto result = binary_search(_elements, delElement);
        if (result.found) {
            _elements = _elements.remove(result.index);
        }
        return this;
    }

    // Set union
    Set opBinary(string op)(in Set otherSet) const if (op == "|")
    out (result) {
        assert(distinct_element_arrays(this, result) && distinct_element_arrays(result, otherSet));
        assert(result.is_superset_of(this));
        assert(result.is_superset_of(otherSet));
        assert(result.cardinality <= cardinality + otherSet.cardinality);
    }
    body {
        mixin WorkAroundClassCmpLimitations!T;
        mixin WorkAroundConstLimitations!T;
        auto set_union = Set();
        set_union._elements.reserve(_elements.length + otherSet._elements.length);
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(otherSet._elements[os_i])) {
                set_union._elements ~= WA_ASSIGN_ECAST(_elements[this_i++]);
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                set_union._elements ~= WA_ASSIGN_ECAST(otherSet._elements[os_i++]);
            } else {
                set_union._elements ~= WA_ASSIGN_ECAST(_elements[this_i++]);
                os_i++;
            }
        }
        // Add the (one or less) tail if any
        if (this_i < _elements.length) {
            set_union._elements ~= WA_ASSIGN_ACAST(_elements[this_i .. $]);
        } else if (os_i < otherSet._elements.length) {
            set_union._elements ~= WA_ASSIGN_ACAST(otherSet._elements[os_i .. $]);
        }
        return set_union;
    }

    // Set difference
    Set opBinary(string op)(in Set otherSet) const if (op == "-")
    out (result) {
        assert(distinct_element_arrays(this, result) && distinct_element_arrays(result, otherSet));
        assert(!result.is_superset_of(otherSet));
        assert(result.is_subset_of(this));
        foreach(element; elements) {
            assert(result.contains(element) || otherSet.contains(element));
        }
    }
    body {
        mixin WorkAroundClassCmpLimitations!T;
        mixin WorkAroundConstLimitations!T;
        auto set_difference = Set();
        set_difference._elements.reserve(_elements.length);
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(otherSet._elements[os_i])) {
                set_difference._elements ~= WA_ASSIGN_ECAST(_elements[this_i++]);
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                os_i++;
            } else {
                this_i++;
                os_i++;
            }
        }
        if (this_i < _elements.length) {
            set_difference._elements ~= WA_ASSIGN_ACAST(_elements[this_i .. $]);
        }
        return set_difference;
    }

    // Symetric set difference
    Set opBinary(string op)(in Set otherSet) const if (op == "^")
    out (result) {
        assert(distinct_element_arrays(this, result) && distinct_element_arrays(result, otherSet));
        foreach(element; elements) {
            assert(result.contains(element) || otherSet.contains(element));
        }
        foreach(element; otherSet.elements) {
            assert(result.contains(element) || contains(element));
        }
        foreach(element; result.elements) {
            assert(contains(element) || otherSet.contains(element));
        }
    }
    body {
        mixin WorkAroundClassCmpLimitations!T;
        mixin WorkAroundConstLimitations!T;
        auto symetric_set_difference = Set();
        symetric_set_difference._elements.reserve(_elements.length + otherSet._elements.length);
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(cast(T)otherSet._elements[os_i])) {
                symetric_set_difference._elements ~= WA_ASSIGN_ECAST(_elements[this_i]);
                this_i++;
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                symetric_set_difference._elements ~= WA_ASSIGN_ECAST(otherSet._elements[os_i]);
                os_i++;
            } else {
                this_i++;
                os_i++;
            }
        }
        // Add the (one or less) tail if any
        if (this_i < _elements.length) {
            symetric_set_difference._elements ~= WA_ASSIGN_ACAST(_elements[this_i .. $]);
        } else if (os_i < otherSet._elements.length) {
            symetric_set_difference._elements ~= WA_ASSIGN_ACAST(otherSet._elements[os_i .. $]);
        }
        return symetric_set_difference;
    }

    // Set intersection
    Set opBinary(string op)(in Set otherSet) const if (op == "&")
    out (result) {
        assert(distinct_element_arrays(this, result) && distinct_element_arrays(result, otherSet));
        foreach(element; elements) {
            assert(result.contains(element) || !otherSet.contains(element));
        }
        foreach(element; otherSet.elements) {
            assert(result.contains(element) || !contains(element));
        }
        foreach(element; result.elements) {
            assert(contains(element) && otherSet.contains(element));
        }
    }
    body {
        mixin WorkAroundClassCmpLimitations!T;
        mixin WorkAroundConstLimitations!T;
        auto set_intersection = Set();
        set_intersection._elements.reserve(min(_elements.length, otherSet._elements.length));
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(otherSet._elements[os_i])) {
                this_i++;
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                os_i++;
            } else {
                set_intersection._elements ~= WA_ASSIGN_ECAST(_elements[this_i]);
                this_i++;
                os_i++;
            }
        }
        return set_intersection;
    }

    // Set membership
    bool opBinaryRight(string op)(in T putativeMember) const if (op == "in")
    {
        return binary_search(_elements, putativeMember).found;
    }

    bool contains(in T[] targetElements ...) const
    {
        foreach (targetElement; targetElements) {
            if (!binary_search(_elements, targetElement).found)
                return false;
        }
        return true;
    }

    private bool _simple_superset_of(in Set otherSet) const
    {
        mixin WorkAroundClassCmpLimitations!T;
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if ((_elements.length - this_i) < (otherSet._elements.length - os_i))
                return false;
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(otherSet._elements[os_i])) {
                this_i++;
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                return false;
            } else {
                this_i++;
                os_i++;
            }
        }
        return true;
    }

    bool is_superset_of(in Set otherSet) const
    out (result) {
        auto intersection = this & otherSet;
        assert(result ? intersection == otherSet : intersection.cardinality < otherSet.cardinality);
    }
    body {
        return _elements.length >= otherSet._elements.length && _simple_superset_of(otherSet);
    }

    bool is_proper_superset_of(in Set otherSet) const
    out (result) {
        if (result) {
            assert(this != otherSet && is_superset_of(otherSet));
        } else {
            assert(this == otherSet || !is_superset_of(otherSet));
        }
    }
    body {
        return _elements.length > otherSet._elements.length && _simple_superset_of(otherSet);
    }

    bool is_subset_of(in Set otherSet) const
    out (result) {
        auto intersection = this & otherSet;
        assert(result ? intersection == this : intersection.cardinality < cardinality);
    }
    body {
        return otherSet.is_superset_of(this);
    }

    bool is_proper_subset_of(in Set otherSet) const
    out (result) {
        if (result) {
            assert(this != otherSet && is_subset_of(otherSet));
        } else {
            assert(this == otherSet || !is_subset_of(otherSet));
        }
    }
    body {
        return otherSet.is_proper_superset_of(this);
    }

    bool is_disjoint_from(in Set otherSet) const
    out (result) {
        // TODO: segment fault: assert(result == otherSet.is_disjoint_from(this));
        auto count = 0;
        foreach (element; _elements) if (element in otherSet) count++;
        assert(result ? count == 0 : count > 0);
    }
    body {
        mixin WorkAroundClassCmpLimitations!T;
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (WA_CMP_ECAST(_elements[this_i]) < WA_CMP_ECAST(otherSet._elements[os_i])) {
                this_i++;
            } else if (WA_CMP_ECAST(otherSet._elements[os_i]) < WA_CMP_ECAST(_elements[this_i])) {
                os_i++;
            } else {
                return false;
            }
        }
        return true;
    }

    bool opEquals(in Set otherSet) const
    {
        return _elements == otherSet._elements;
    }

    string toString() const
    {
        mixin WorkAroundConstLimitations!T;
        if (_elements.length == 0) return "Set{}";
        auto str = format("Set{%s", WA_ASSIGN_ECAST(_elements[0]));
        foreach (element; _elements[1 .. $]) {
            str ~= format(", %s", WA_ASSIGN_ECAST(element));
        }
        str ~= "}";
        return str;
    }
}
unittest {
    //import std.stdio;
    import std.conv;
    // TODO: write a more thorough Sets unittest
    auto iset = Set!int();
    iset.add(1, 4, 2, 4, 2);
    assert(iset.cardinality == 3);
    assert(iset.elements == [1, 2, 4]);
    auto xset = Set!int(4, 2, 1, 4, 2);
    assert(xset.cardinality == 3);
    assert(xset == iset);
    assert((iset | xset).cardinality == 3);
    auto uset = iset | xset;
    assert(uset.cardinality == 3);
    xset.add(5);
    iset.add(7);
    assert((xset & iset) == uset);
    assert(uset.is_superset_of(uset));
    assert(uset.is_subset_of(uset));
    assert(uset.is_subset_of(iset));
    assert(uset.is_proper_subset_of(iset));
    assert(iset.is_superset_of(uset));
    assert(iset.is_proper_superset_of(uset));
    assert(!uset.is_superset_of(iset));
    assert(xset != iset);
    assert(uset.cardinality == 3);
    uset.add(9);
    assert(9 !in iset);
    assert(9 !in xset);
    assert(5 in xset);
    auto cset = uset.clone;
    assert(cset == uset);
    cset.remove(1, 4);
    assert((uset - cset).elements == [1, 4]);
    auto uset2 = uset | iset;
    auto dset2 = uset - iset;

    assert((Set!int(1, 3, 5) |= Set!int(2, 3, 4, 6)).elements == [1, 2, 3, 4, 5, 6]);
    assert((Set!int(1, 3, 5) += 2).elements == [1, 2, 3, 5]);
    assert((Set!int(1, 3, 5) += 3).elements == [1, 3, 5]);
    assert((Set!int(1, 3, 5) -= Set!int(2, 3, 4, 6)).elements == [1, 5]);
    assert((Set!int(1, 3, 5) -= 2).elements == [1, 3, 5]);
    assert((Set!int(1, 3, 5) -= 3).elements == [1, 5]);
    assert((Set!int(1, 3, 5) ^ Set!int(2, 3, 4, 6)).elements == [1, 2, 4, 5, 6]);
    assert((Set!int(1, 3, 5) ^ Set!int(1, 3, 5)).elements == []);
    assert((Set!int(3, 5, 1)).toString() == "Set{1, 3, 5}");
    assert(to!string(iset) == "Set{1, 2, 4, 7}");
    auto odds = Set!int(1, 3, 5, 7, 9, 11, 13);
    auto evens = Set!int(0, 2, 4, 6, 8, 10);
    assert(odds.is_disjoint_from(evens));
    assert(evens.is_disjoint_from(odds));
    assert(!evens.is_disjoint_from(iset));
    assert((odds | evens) == (evens | odds));
    assert((odds & evens) == (evens & odds));
    assert((odds ^ evens) == (evens ^ odds));
    assert(!odds.is_proper_superset_of(evens));
    assert(!odds.is_proper_subset_of(evens));
    auto count = 0;
    foreach(e; odds) {
        assert(odds._elements[count] == e);
        count++;
    }
    assert(count == odds.cardinality);
    count = 0;
    foreach(e; odds) {
        assert(odds._elements[count] == e);
        count++;
        if (count == 3) break;
    }
    assert(count == 3);
    uset = (xset | iset);
    // This part's purpose is to find problems associated using
    // classes as items caused by a bug in D's design
    class Dummy {
        int val;
        this(int ival) { val = ival; };
        override int opCmp(Object o)
        {
            return val - (cast(Dummy) o).val;
        }
        override bool opEquals(Object o)
        {
            return val == (cast(Dummy) o).val;
        }
        override string toString() const {
            return format("Dummy(%s)", val);
        }
    }
    Dummy[] dlist = [new Dummy(1), new Dummy(4), new Dummy(2), new Dummy(3)];
    auto dummyset = Set!Dummy(dlist);
    Dummy[] dlist2 = [new Dummy(5), new Dummy(4), new Dummy(1), new Dummy(3)];
    auto dummyset2 = Set!Dummy(dlist2);
    auto d3 = dummyset | dummyset2;
    auto d4 = dummyset - dummyset2;
    auto d5 = dummyset ^ dummyset2;
    auto d6 = dummyset & dummyset2;
    assert(to!string(dummyset) == "Set{Dummy(1), Dummy(2), Dummy(3), Dummy(4)}");
}

private bool distinct_element_arrays(T)(const Set!T s1, const Set!T s2)
{
    // For use in asserting that two sets do not share _element arrays
    return s1._elements is null || s1._elements !is s2._elements;
}

private bool is_ordered_no_dups(T)(in T[] list)
{
    mixin WorkAroundClassCmpLimitations!T;
    for (auto j = 1; j < list.length; j++) {
        if (WA_CMP_ECAST(list[j - 1]) >= WA_CMP_ECAST(list[j]))
            return false;
    }
    return true;
}
unittest {
    assert(is_ordered_no_dups(new int[0]));
    assert(is_ordered_no_dups([1]));
    assert(!is_ordered_no_dups([1, 1]));
    assert(is_ordered_no_dups([1, 2, 3, 4, 5, 6, 7]));
    assert(!is_ordered_no_dups([1, 2, 4, 3, 5, 6, 7]));
    assert(!is_ordered_no_dups([1, 2, 3, 5, 5, 6, 7]));
}

private T[] remove_adj_dups(T)(T[] list)
out (result) {
    for (auto i = 1; i < result.length; i++) {
        assert(result[i - 1] != result[i]);
    }
    foreach (item; list) {
        assert(find(result, item)[0] == item);
    }
}
body {
    if (list.length > 1) {
        // Remove any duplicates
        size_t last_index = 0;
        for (size_t index = 1; index < list.length; index++) {
            if (list[index] != list[last_index]) {
                list[++last_index] = list[index];
            }
        }
        list.length = last_index + 1;
    }
    return list;
}
unittest {
    int[] empty;
    assert(remove_adj_dups(empty) == []);
    assert(remove_adj_dups([1]) == [1]);
    assert(remove_adj_dups([1, 1]) == [1]);
    assert(remove_adj_dups([5, 1, 1, 5, 6, 6, 3]) == [5, 1, 5, 6, 3]);
}

struct BinarySearchResult {
    bool found; // whether the item was found
    size_t index; // location of item if found else "insert before" point
}

BinarySearchResult binary_search(T)(in T[] list, in T item)
in {
    assert(is_ordered_no_dups(list));
}
out (result) {
    mixin WorkAroundClassCmpLimitations!T;
    if (result.found) {
        assert(WA_CMP_ECAST(list[result.index]) == WA_CMP_ECAST(item));
    } else {
        assert(result.index == list.length || WA_CMP_ECAST(list[result.index]) > WA_CMP_ECAST(item));
        assert(result.index == 0 || WA_CMP_ECAST(list[result.index - 1]) < WA_CMP_ECAST(item));
    }
}
body {
    mixin WorkAroundClassCmpLimitations!T;
    // unsigned array indices make this prudent or imax could go out of range
    if (list.length == 0 || WA_CMP_ECAST(item) < WA_CMP_ECAST(list[0]))
        return BinarySearchResult(false, 0);
    auto imax = list.length - 1;
    typeof(imax) imin = 0;

    while (imax >= imin) {
        typeof(imax) imid = (imin + imax) / 2;
        if (WA_CMP_ECAST(list[imid]) < WA_CMP_ECAST(item)) {
            imin = imid + 1;
        } else if (WA_CMP_ECAST(list[imid]) > WA_CMP_ECAST(item)) {
            imax = imid - 1;
        } else {
            return BinarySearchResult(true, imid);
        }
    }
    assert(imin >= imax);
    return BinarySearchResult(false, imin);
}
unittest {
    assert(binary_search!int([], 5) == BinarySearchResult(false, 0));
    assert(binary_search!int([5], 5) == BinarySearchResult(true, 0));
    assert(binary_search!int([5], 6) == BinarySearchResult(false, 1));
    assert(binary_search!int([5], 4) == BinarySearchResult(false, 0));
    auto testlist = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23];
    for (auto i = 0; i < testlist.length; i++) {
        assert(binary_search(testlist, testlist[i]) == BinarySearchResult(true, i));
        assert(binary_search(testlist, testlist[i] - 1) == BinarySearchResult(false, i));
    }
}

Set!T extract_key_set(T, G)(const(G[T]) assocArray)
out (result) {
    assert(result.cardinality == assocArray.length);
    foreach(element; result.elements)
        assert(element in assocArray);
}
body {
    return Set!T(assocArray.keys);
}

unittest {
    auto test = [1: 2, 7 : 8, 3 : 4];
    assert(extract_key_set(test).elements == [1, 3, 7]);
}
