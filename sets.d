// sets.d
//
// Copyright Peter Williams 2016 <pwil3058@gmail.com>.
//
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module sets;

import std.string: format;
import std.algorithm: copy, find;
import std.traits: isAssignable;
import std.range: retro;

import workarounds: wa_sort;

// for use in unit tests
mixin template DummyClass() {
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

    Dummy[] list_of_dummies(in int[] int_values...)
    body {
        Dummy[] list;
        foreach (int_value; int_values) {
            list ~= new Dummy(int_value);
        }
        return list;
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
    mixin DummyClass;
    // first test list of dummies works
    assert(list_of_dummies(6, 2, 3, 4, 5, 6, 7) == [new Dummy(6), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(5), new Dummy(6), new Dummy(7)]);
    assert(is_ordered([new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(5), new Dummy(6), new Dummy(7)]));
    assert(!is_ordered([new Dummy(1), new Dummy(2), new Dummy(4), new Dummy(3), new Dummy(5), new Dummy(6), new Dummy(7)]));
    assert(is_ordered([new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(5), new Dummy(5), new Dummy(6), new Dummy(7)]));
}

private bool is_ordered_no_dups(T)(in T[] list)
{
    for (auto j = 1; j < list.length; j++) {
        static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
            if (cast(T) list[j - 1] >= cast(T) list[j]) return false;
        } else {
            if (list[j - 1] >= list[j]) return false;
        }
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
    mixin DummyClass;
    assert(is_ordered_no_dups([new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(5), new Dummy(6), new Dummy(7)]));
    assert(!is_ordered_no_dups([new Dummy(1), new Dummy(2), new Dummy(4), new Dummy(3), new Dummy(5), new Dummy(6), new Dummy(7)]));
    assert(!is_ordered_no_dups([new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(5), new Dummy(5), new Dummy(6), new Dummy(7)]));
}

private T[] remove_adj_dups(T)(T[] list)
in {
    assert(is_ordered(list));
}
out (result) {
    for (auto i = 1; i < result.length; i++) assert(result[i - 1] != result[i]);
    foreach (item; list) assert(result.contains(item));
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
    int[] single = [1];
    assert(remove_adj_dups(single) == [1]);
    int[] pair = [1, 1];
    assert(remove_adj_dups(pair) == [1]);
    int[] few = [1, 1, 5, 6, 6, 9];
    assert(remove_adj_dups(few) == [1, 5, 6, 9]);
    assert(remove_adj_dups([1, 1, 5, 6, 6, 6, 6, 7, 8, 9, 9, 9, 9, 9]) == [1, 5, 6, 7, 8, 9]);
    mixin DummyClass;
    Dummy[] dfew = [new Dummy(1), new Dummy(1), new Dummy(5), new Dummy(6), new Dummy(6), new Dummy(9)];
    assert(remove_adj_dups(dfew) == [new Dummy(1), new Dummy(5), new Dummy(6), new Dummy(9)]);
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
    if (result.found) {
        static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
            assert(cast(T) list[result.index] == cast(T) item);
        } else {
            assert(list[result.index] == item);
        }
    } else {
        assert(!list.contains(item));
        static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
            assert(result.index == list.length || cast (T) list[result.index] > cast (T) item);
            assert(result.index == 0 || cast (T) list[result.index - 1] < cast (T) item);
        } else {
            assert(result.index == list.length || list[result.index] > item);
            assert(result.index == 0 || list[result.index - 1] < item);
        }
    }
}
body {
    // unsigned array indices make this prudent or imax could go out of range
    static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
        if (list.length == 0 || cast (T) item < cast (T) list[0]) return BinarySearchResult(false, 0);
    } else {
        if (list.length == 0 || item < list[0]) return BinarySearchResult(false, 0);
    }
    auto imax = list.length - 1;
    typeof(imax) imin = 0;

    while (imax >= imin) {
        typeof(imax) imid = (imin + imax) / 2;
        static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
            if (cast (T) list[imid] < cast (T) item) {
                imin = imid + 1;
            } else if (cast (T) list[imid] > cast (T) item) {
                imax = imid - 1;
            } else {
                return BinarySearchResult(true, imid);
            }
        } else {
            if (list[imid] < item) {
                imin = imid + 1;
            } else if (list[imid] > item) {
                imax = imid - 1;
            } else {
                return BinarySearchResult(true, imid);
            }
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
        assert(binary_search(testlist, testlist[i] + 1) == BinarySearchResult(false, i + 1));
    }
    mixin DummyClass;
    auto ctestlist = [new Dummy(1), new Dummy(3), new Dummy(5), new Dummy(7), new Dummy(9), new Dummy(11), new Dummy(13), new Dummy(15), new Dummy(17), new Dummy(19), new Dummy(21), new Dummy(23)];
    for (auto i = 0; i < ctestlist.length; i++) {
        assert(binary_search(ctestlist,  new Dummy(ctestlist[i].val)) == BinarySearchResult(true, i));
        assert(binary_search(ctestlist, new Dummy(ctestlist[i].val - 1)) == BinarySearchResult(false, i));
        assert(binary_search(ctestlist, new Dummy(ctestlist[i].val + 1)) == BinarySearchResult(false, i + 1));
    }
}

private T[] to_ordered_no_dups(T)(in T[] list...)
out (result) {
    assert(is_ordered_no_dups(result));
    foreach (item; list) assert(result.contains(item));
}
body {
    static if (is(T == class)) { // WORKAROUND: class opCmp() design flaw
        auto list_dup = (cast(T[]) list).dup;
    } else {
        auto list_dup = list.dup;
    }
    return list_dup.wa_sort.remove_adj_dups();;
}
unittest {
    int[] empty;
    assert(to_ordered_no_dups(empty) == []);
    int[] single = [1];
    assert(to_ordered_no_dups(single) == [1]);
    int[] pair = [1, 1];
    assert(to_ordered_no_dups(pair) == [1]);
    int[] few = [5, 1, 1, 5, 6, 6, 3];
    assert(to_ordered_no_dups(few) == [1, 3, 5, 6]);
    assert(to_ordered_no_dups(9, 5, 1, 1, 5, 6, 6, 6, 3, 1, 7, 9) == [1, 3, 5, 6, 7, 9]);
    mixin DummyClass;
    Dummy[] dfew = [new Dummy(5), new Dummy(1), new Dummy(1), new Dummy(5), new Dummy(6), new Dummy(6), new Dummy(3)];
    assert(to_ordered_no_dups(dfew) == [new Dummy(1), new Dummy(3), new Dummy(5), new Dummy(6)]);
}

private ref T[] insert(T)(ref T[] list, in T item)
in {
    assert(is_ordered_no_dups(list));
}
out (result) {
    assert(is_ordered_no_dups(result));
    assert(result.contains(item));
    foreach (i; list)  assert(result.contains(i));
}
body {
    auto bsr = binary_search(list, item);
    if (!bsr.found) {
        static if (!isAssignable!(T, const(T))) {
            list ~= cast(T) item;
        } else {
            list ~= item;
        }
        if (list.length > 1 && bsr.index < list.length - 1) {
            copy(retro(list[bsr.index .. $ - 1]), retro(list[bsr.index + 1 .. $]));
            static if (!isAssignable!(T, const(T))) {
                list[bsr.index] = cast(T) item;
            } else {
                list[bsr.index] = item;
            }
        }
    }
    return list;
}
unittest {
    auto list = [2, 4, 8, 16, 32];
    assert(insert(list, 1) == [1, 2, 4, 8, 16, 32]);
    assert(insert(list, 1) == [1, 2, 4, 8, 16, 32]);
    assert(insert(list, 64) == [1, 2, 4, 8, 16, 32, 64]);
    assert(insert(list, 64) == [1, 2, 4, 8, 16, 32, 64]);
    assert(insert(list, 3) == [1, 2, 3, 4, 8, 16, 32, 64]);
    assert(insert(list, 7) == [1, 2, 3, 4, 7, 8, 16, 32, 64]);
    assert(insert(list, 21) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64]);
    assert(insert(list, 64) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64]);
    assert(insert(list, 1) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64]);
    foreach (item; [1, 2, 3, 4, 7, 8, 16, 21, 32, 64]) assert(insert(list, item) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64]);
    mixin DummyClass;
    Dummy[] dlist = [new Dummy(2), new Dummy(4), new Dummy(8), new Dummy(16), new Dummy(32)];
    assert(insert(dlist, new Dummy(1)).length == 6);
}

private ref T[] remove(T)(ref T[] list, in T item)
in {
    assert(is_ordered_no_dups(list));
}
out (result) {
    assert(is_ordered_no_dups(result));
    assert(!result.contains(item));
    foreach (i; list) if (i != item) assert(result.contains(i));
}
body {
    auto bsr = binary_search(list, item);
    if (bsr.found) {
        copy(list[bsr.index + 1..$], list[bsr.index..$ - 1]);
        list.length--;
    }
    return list;
}
unittest {
    auto list = [1, 2, 3, 4, 7, 8, 16, 21, 32, 64];
    assert(remove(list, 1) == [2, 3, 4, 7, 8, 16, 21, 32, 64]);
    assert(remove(list, 64) == [2, 3, 4, 7, 8, 16, 21, 32]);
    assert(remove(list, 3) == [2, 4, 7, 8, 16, 21, 32]);
    assert(remove(list, 7) == [2, 4, 8, 16, 21, 32]);
    assert(remove(list, 21) == [2, 4, 8, 16, 32]);
    mixin DummyClass;
    Dummy[] dlist = [new Dummy(2), new Dummy(4), new Dummy(8), new Dummy(16), new Dummy(32)];
    assert(remove(dlist, dlist[0]).length == 4);
}

private T[] set_union(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    assert(is_ordered_no_dups(result));
    foreach (i; list1) assert(result.contains(i));
    foreach (i; list2) assert(result.contains(i));
    foreach (i; result) assert(list1.contains(i) || list2.contains(i));
}
body {
    T[] su;
    su.reserve(list1.length + list2.length);
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            static if (isAssignable!(T, const(T))) {
                su ~=  list1[i_1++];
            } else {
                su ~= cast(T) list1[i_1++];
            }
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            static if (isAssignable!(T, const(T))) {
                su ~= list2[i_2++];
            } else {
                su ~= cast(T) list2[i_2++];
            }
        } else {
            static if (isAssignable!(T, const(T))) {
                su ~= list1[i_1++];
            } else {
                su ~= cast(T) list1[i_1++];
            }
            i_2++;
        }
    }
    // Add the (one or less) tail if any
    if (i_1 < list1.length) {
        static if (isAssignable!(T, const(T))) {
            su ~= list1[i_1..$];
        } else {
            su ~= cast(T[]) list1[i_1..$];
        }
    } else if (i_2 < list2.length) {
        static if (isAssignable!(T, const(T))) {
            su ~= list2[i_2..$];
        } else {
            su ~= cast(T[]) list2[i_2..$];
        }
    }
    return su;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    assert(set_union(list1, list2) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64, 128]);
    assert(set_union(list2, list1) == [1, 2, 3, 4, 7, 8, 16, 21, 32, 64, 128]);
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(set_union(dlist1, dlist2) == set_union(dlist2, dlist1));
}

private T[] set_intersection(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    assert(is_ordered_no_dups(result));
    foreach (i; list1) if (list2.contains(i)) assert(result.contains(i));
    foreach (i; list2) if (list1.contains(i)) assert(result.contains(i));
    foreach (i; result) assert(list1.contains(i) && list2.contains(i));
}
body {
    T[] su;
    su.reserve(list1.length < list2.length ? list1.length : list2.length);
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            i_1++;
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            i_2++;
        } else {
            static if (isAssignable!(T, const(T))) {
                su ~= list1[i_1++];
            } else {
                su ~= cast(T) list1[i_1++];
            }
            i_2++;
        }
    }
    return su;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    assert(set_intersection(list1, list2) == [2, 7, 21, 64]);
    assert(set_intersection(list2, list1) == [2, 7, 21, 64]);
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(set_intersection(dlist1, dlist2) == set_intersection(dlist2, dlist1));
}

private T[] symmetric_set_difference(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    assert(is_ordered_no_dups(result));
    foreach (i; list1) if (!list2.contains(i)) assert(result.contains(i));
    foreach (i; list2) if (!list1.contains(i)) assert(result.contains(i));
    foreach (i; result) assert((list1.contains(i) && !list2.contains(i)) || (list2.contains(i) && !list1.contains(i)));
}
body {
    T[] su;
    su.reserve(list1.length + list2.length);
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            static if (isAssignable!(T, const(T))) {
                su ~=  list1[i_1++];
            } else {
                su ~= cast(T) list1[i_1++];
            }
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            static if (isAssignable!(T, const(T))) {
                su ~= list2[i_2++];
            } else {
                su ~= cast(T) list2[i_2++];
            }
        } else {
            i_1++;
            i_2++;
        }
    }
    // Add the (one or less) tail if any
    if (i_1 < list1.length) {
        static if (isAssignable!(T, const(T))) {
            su ~= list1[i_1..$];
        } else {
            su ~= cast(T[]) list1[i_1..$];
        }
    } else if (i_2 < list2.length) {
        static if (isAssignable!(T, const(T))) {
            su ~= list2[i_2..$];
        } else {
            su ~= cast(T[]) list2[i_2..$];
        }
    }
    return su;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    assert(symmetric_set_difference(list1, list2) == [1, 3, 4, 8, 16, 32, 128]);
    assert(symmetric_set_difference(list2, list1) == [1, 3, 4, 8, 16, 32, 128]);
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(symmetric_set_difference(dlist1, dlist2) == symmetric_set_difference(dlist2, dlist1));
}

private T[] set_difference(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    assert(is_ordered_no_dups(result));
    foreach (i; list1) if (!list2.contains(i)) assert(result.contains(i));
    foreach (i; list2) assert(!result.contains(i));
    foreach (i; result) assert(list1.contains(i) && !list2.contains(i));
}
body {
    T[] su;
    su.reserve(list1.length + list2.length);
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            static if (isAssignable!(T, const(T))) {
                su ~=  list1[i_1++];
            } else {
                su ~= cast(T) list1[i_1++];
            }
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            i_2++;
        } else {
            i_1++;
            i_2++;
        }
    }
    // Add the (one or less) tail if any
    if (i_1 < list1.length) {
        static if (isAssignable!(T, const(T))) {
            su ~= list1[i_1..$];
        } else {
            su ~= cast(T[]) list1[i_1..$];
        }
    }
    return su;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    assert(set_difference(list1, list2) == [8, 16, 32]);
    assert(set_difference(list2, list1) == [1, 3, 4, 128]);
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(disjoint(set_difference(dlist1, dlist2), set_difference(dlist2, dlist1)));
}

private bool disjoint(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    auto count = 0;
    foreach (i; list1) if (list2.contains(i)) count++;
    foreach (i; list2) if (list1.contains(i)) count++;
    assert(result == (count == 0));
}
body {
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            i_1++;
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            i_2++;
        } else {
            return false;
        }
    }
    return true;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    assert(!disjoint(list1, list2));
    assert(!disjoint(list2, list1));
    assert(disjoint([8, 16, 32], [1, 3, 4, 128]));
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(disjoint(dlist1, dlist2) == disjoint(dlist2, dlist1));
}

private bool contains(T)(in T[] list1, in T[] list2)
in {
    assert(is_ordered_no_dups(list1) && is_ordered_no_dups(list2));
}
out (result) {
    auto count = 0;
    foreach (i; list2) if (list1.contains(i)) count++;
    assert(result == (count == list2.length));
}
body {
    size_t i_1, i_2;
    while (i_1 < list1.length && i_2 < list2.length) {
        if (cast(T) list1[i_1] < cast(T) list2[i_2]) { // WORKAROUND: class opCmp() design flaw
            i_1++;
        } else if (cast(T) list2[i_2] < cast(T) list1[i_1]) { // WORKAROUND: class opCmp() design flaw
            return false;
        } else {
            i_1++;
            i_2++;
        }
    }
    return i_2 == list2.length;
}
unittest {
    auto list1 = [2, 7, 8, 16, 21, 32, 64];
    auto list2 = [1, 2, 3, 4, 7, 21, 64, 128];
    auto list3 = set_difference(list1, list2);
    auto list4 = set_difference(list2, list3);
    assert(list1.contains(list1));
    assert(!list1.contains(list2));
    assert(list1.contains(list3));
    assert(!list1.contains(list4));
    assert(list2.contains(list2));
    assert(!list2.contains(list1));
    assert(!list2.contains(list3));
    assert(list2.contains(list4));
    mixin DummyClass;
    auto dlist1 = [new Dummy(2), new Dummy(7), new Dummy(8), new Dummy(16), new Dummy(21), new Dummy(32), new Dummy(64)];
    auto dlist2 = [new Dummy(1), new Dummy(2), new Dummy(3), new Dummy(4), new Dummy(7), new Dummy(21), new Dummy(64), new Dummy(128)];
    assert(contains(dlist1, dlist2) == contains(dlist2, dlist1));
}

private string to_string(T)(const T[] list)
{
    if (list.length == 0) return "[]";
    string str = format("[%s", cast(T)list[0]);
    foreach (element; list[1..$]) {
        str ~= format(", %s", cast(T)element);
    }
    str ~= "]";
    return str;
}

private bool distinct_lists(T)(const T[] list1, const T[] list2)
{
    return list1 is null || list1 !is list2;
}
unittest {
    assert(distinct_lists([1, 2, 3], [1, 2, 3]));
    auto list = [1, 2, 3, 4, 5];
    auto list_d = list;
    assert(!distinct_lists(list, list_d));
    assert(distinct_lists(list, list.dup));
    int[] list_e;
    assert(distinct_lists(list_e, list_e));
    auto list_ed = list_e.dup;
    list_e ~= 2;
    list_ed ~= 2;
    assert(distinct_lists(list_e, list_ed));
}

struct Set(T) {
    protected T[] _elements;
    invariant () {
        assert(is_ordered_no_dups(_elements), _elements.to_string());
    }

    this(in T[] initial_items...)
    out {
        assert(_elements.length <= initial_items.length);
        foreach (item; initial_items) assert(_elements.contains(item));
    }
    body {
        static if (!isAssignable!(T, const(T))) {
            _elements = (cast(T[]) initial_items).dup.wa_sort.remove_adj_dups();
        } else {
            _elements = initial_items.dup.wa_sort.remove_adj_dups();
        }
    }

    @property
    size_t cardinality() const
    {
        return _elements.length;
    }

    @property
    T[] elements() const
    out (result) {
        assert(result == _elements, _elements.to_string());
        assert(distinct_lists(result, _elements), _elements.to_string());
    }
    body {
        static if (!isAssignable!(T, const(T))) {
            return (cast(T[]) _elements).dup;
        } else {
            return _elements.dup;
        }
    }

    Set clone() const
    out (result) {
        assert(distinct_lists(result._elements, _elements));
        assert(result._elements == _elements);
        assert(result !is this || this is Set());
    }
    body {
        auto clone_set = Set();
        static if (!isAssignable!(T, const(T))) {
            clone_set._elements = (cast(T[])_elements).dup;
        } else {
            clone_set._elements = _elements.dup;
        }
        return clone_set;
    }

    bool opEquals(in Set other_set) const
    {
        return _elements == other_set._elements;
    }

    bool opBinaryRight(string op)(in T putative_member) const if (op == "in")
    out (result) {
       assert(result ? _elements.contains(putative_member) : !_elements.contains(putative_member));
    }
    body {
        return _elements.binary_search(putative_member).found;
    }

    bool is_disjoint_from(in Set other_set) const
    body {
        return _elements.disjoint(other_set._elements);
    }

    bool is_proper_subset_of(in Set other_set) const
    body {
        return _elements.length < other_set._elements.length && other_set._elements.contains(_elements);
    }

    bool is_proper_superset_of(in Set other_set) const
    body {
        return _elements.length > other_set._elements.length && _elements.contains(other_set._elements);
    }

    bool is_subset_of(in Set other_set) const
    body {
        return other_set._elements.contains(_elements);
    }

    bool is_superset_of(in Set other_set) const
    body {
        return _elements.contains(other_set._elements);
    }

    bool contains(in T[] putative_members ...) const
    {
        foreach (putative_member; putative_members) {
            if (!_elements.binary_search(putative_member).found)
                return false;
        }
        return true;
    }

    ref Set opOpAssign(string op)(in T new_item) if (op == "+" || op == "-")
    out {
        static if (op == "+") {
            assert(_elements.contains(new_item));
        } else if (op == "-") {
            assert(!_elements.contains(new_item));
        } else {
            assert(false);
        }
    }
    body {
        static if (op == "+") {
            _elements.insert(new_item);
        } else if (op == "-") {
            _elements.remove(new_item);
        } else {
            assert(false);
        }
        return this;
    }

    void add(in T[] new_items...)
    out {
        foreach (new_item; new_items) assert(_elements.contains(new_item));
    }
    body {
        foreach(new_item; new_items) {
            _elements.insert(new_item);
        }
    }

    void remove(in T[] new_items...)
    out {
        foreach (new_item; new_items) assert(!_elements.contains(new_item));
    }
    body {
        foreach(new_item; new_items) {
            _elements.remove(new_item);
        }
    }

    Set opBinary(string op)(in Set other_set) const if (op == "|" || op == "&" || op == "-" || op == "^")
    out (result) {
        foreach (set; [this, other_set]) {
            assert(result !is set || set is Set(), format("%s %s %s %s %s", op, set, this, other_set, result));
            assert(distinct_lists(result._elements, set._elements));
        }
        static if (op == "|") {
            foreach (item; result._elements) assert(this._elements.contains(item) || other_set._elements.contains(item));
            foreach (set; [this, other_set]) {
                foreach (item; set._elements) assert(result._elements.contains(item));
            }
        } else if (op == "&") {
            foreach (item; result._elements) assert(this._elements.contains(item) && other_set._elements.contains(item));
            foreach (item; _elements) assert(result._elements.contains(item) || !other_set._elements.contains(item));
            foreach (item; other_set._elements) assert(result._elements.contains(item) || !_elements.contains(item));
        } else if (op == "-") {
            foreach (item; result._elements) assert(this._elements.contains(item) && !other_set._elements.contains(item));
            foreach (item; _elements) assert(result._elements.contains(item) ? !other_set._elements.contains(item) : other_set._elements.contains(item));
        } else if (op == "^") {
            foreach (item; result._elements) assert(this._elements.contains(item) ? !other_set._elements.contains(item) : other_set._elements.contains(item));
            foreach (item; _elements) assert(result._elements.contains(item) ? !other_set._elements.contains(item) : other_set._elements.contains(item));
            foreach (item; other_set._elements) assert(result._elements.contains(item) ? !_elements.contains(item) : _elements.contains(item));
        } else {
            assert(false);
        }
    }
    body {
        auto new_set = Set();
        static if (op == "|") {
            new_set._elements = _elements.set_union(other_set._elements);
        } else if (op == "&") {
            new_set._elements = _elements.set_intersection(other_set._elements);
        } else if (op == "-") {
            new_set._elements = _elements.set_difference(other_set._elements);
        } else if (op == "^") {
            new_set._elements = _elements.symmetric_set_difference(other_set._elements);
        } else {
            assert(false);
        }
        return new_set;
    }

    ref Set opOpAssign(string op)(in Set other_set) if (op == "|" || op == "-" || op == "^" || op == "&")
    out (result) {
        assert(result is this);
        // NB: without access to "before" state we can't do reasonable tests
    }
    body {
        static if (op == "|") {
            _elements = _elements.set_union(other_set._elements);
        } else if (op == "&") {
            _elements = _elements.set_intersection(other_set._elements);
        } else if (op == "-") {
            _elements = _elements.set_difference(other_set._elements);
        } else if (op == "^") {
            _elements = _elements.symmetric_set_difference(other_set._elements);
        } else {
            assert(false);
        }
        return this;
    }

    int opApply(int delegate(T) dg)
    out {
        assert(is_ordered_no_dups(_elements), _elements.to_string());
    }
    body {
        foreach (element; _elements) {
            auto result = dg(element);
            if (result) return result;
        }
        return 0;
    }

    string toString() const
    body {
        if (_elements.length == 0) return "Set{}";
        static if (!isAssignable!(T, const(T))) {
            auto str = format("Set{%s", cast(T) _elements[0]);
            foreach (element; _elements[1..$]) {
                str ~= format(", %s", cast(T) element);
            }
        } else {
            auto str = format("Set{%s", _elements[0]);
            foreach (element; _elements[1..$]) {
                str ~= format(", %s", element);
            }
        }
            str ~= "}";
        return str;
    }
}
unittest {
    import std.random;
    auto int_set = Set!int();
    assert(int_set.cardinality == 0);
    int_set.add(3, 4, 5, 2, 8, 17, 5, 4);
    assert(int_set.elements == [2, 3, 4, 5, 8, 17]);
    assert(Set!int(3, 4, 5, 2, 8, 17, 5, 4).cardinality == 6);
    assert(Set!int(3, 4, 5, 2, 8, 17, 5, 4).elements == [2, 3, 4, 5, 8, 17]);
    assert(8 in Set!int(3, 4, 5, 2, 8, 17, 5, 4));
    assert(8 !in (Set!int(3, 4, 5, 2, 8, 17, 5, 4) -= 8));
    assert(11 !in Set!int(3, 4, 5, 2, 8, 17, 5, 4));
    assert(11 in (Set!int(3, 4, 5, 2, 8, 17, 5, 4) += 11));
    assert((Set!int(3, 9, 4, 5, 3) | Set!int(1, 3, 5, 7)).elements == [1, 3, 4, 5, 7, 9]);
    assert((Set!int(3, 9, 4, 5, 3) & Set!int(1, 3, 5, 7)).elements == [3, 5]);
    assert((Set!int(3, 9, 4, 5, 3) - Set!int(1, 3, 5, 7)).elements == [4, 9]);
    assert((Set!int(3, 9, 4, 5, 3) ^ Set!int(1, 3, 5, 7)).elements == [1, 4, 7, 9], (Set!int(3, 9, 4, 5, 3) ^ Set!int(1, 3, 5, 7)).toString());
    assert((Set!int(3, 9, 4, 5, 3) |= Set!int(1, 3, 5, 7)).elements == [1, 3, 4, 5, 7, 9]);
    assert((Set!int(3, 9, 4, 5, 3) &= Set!int(1, 3, 5, 7)).elements == [3, 5]);
    assert((Set!int(3, 9, 4, 5, 3) -= Set!int(1, 3, 5, 7)).elements == [4, 9]);
    assert((Set!int(3, 9, 4, 5, 3) ^= Set!int(1, 3, 5, 7)).elements == [1, 4, 7, 9], (Set!int(3, 9, 4, 5, 3) ^ Set!int(1, 3, 5, 7)).toString());
    mixin DummyClass;
    auto dummy_set = Set!Dummy();
    assert(dummy_set.cardinality == 0);
    dummy_set.add(list_of_dummies(3, 4, 5, 2, 8, 17, 5, 4));
    assert(dummy_set.elements == list_of_dummies(2, 3, 4, 5, 8, 17));
    assert(Set!Dummy(list_of_dummies(3, 4, 5, 2, 8, 17, 5, 4)).cardinality == 6);
    assert(Set!Dummy(list_of_dummies(3, 4, 5, 2, 8, 17, 5, 4)).elements.length == 6);
    assert(new Dummy(8) in Set!Dummy(list_of_dummies(3, 4, 5, 2, 8, 17, 5, 4)));
    assert(new Dummy(11) in (Set!Dummy(list_of_dummies(3, 4, 5, 2, 8, 17, 5, 4)) += new Dummy(11)));
    assert(dummy_set.cardinality == 6);
    assert((Set!Dummy(list_of_dummies(3, 9, 4, 5, 3)) | Set!Dummy(list_of_dummies(1, 3, 5, 7))).elements == list_of_dummies(1, 3, 4, 5, 7, 9));
    int [] random_list(int len, int min_val, int max_val)
    body {
        int[] list;
        for (auto i = 0; i < len; i++) list ~= uniform(min_val, max_val);
        return list;
    }
    for (auto i = 0; i < 100; i++) {
        auto set_i = Set!int();
        set_i.add(random_list(16, 0, 24));
        set_i.remove(random_list(16, 0, 24));
        auto set_u = Set!int(random_list(i, 0, 24)) | Set!int(random_list(i + 2, 0, 24));
        auto set_d = Set!int(random_list(i, 0, 24)) - Set!int(random_list(i + 2, 0, 24));
        auto set_a = Set!int(random_list(i, 0, 24)) & Set!int(random_list(i + 2, 0, 24));
        auto set_sd = Set!int(random_list(i, 0, 24)) ^ Set!int(random_list(i + 2, 0, 24));
        set_u |= Set!int(random_list(i, 0, 24));
        set_u ^= Set!int(random_list(i, 0, 24));
        set_u &= Set!int(random_list(i, 0, 24));
        set_u -= Set!int(random_list(i, 0, 24));
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
