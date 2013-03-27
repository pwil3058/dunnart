module sets;

import std.string;

class Set(T) {
    protected T[] _elements;
    invariant () {
        static if (is(T == class)) {
            // WORKAROUND: Cast needed because of opCmp signature
            assert(strictly_ordered(cast(T[])_elements));
        } else {
            assert(strictly_ordered(_elements));
        }
    }

    this(T[] initialElements...) {
        add(initialElements);
    }

    @property size_t
    cardinality()
    {
        return _elements.length;
    }

    @property T[]
    elements()
    {
        return _elements.dup;
    }

    Set!T
    clone()
    {
        auto cloneSet = new Set!T;
        cloneSet._elements = _elements.dup;
        return cloneSet;
    }

    void
    add(T[] newElements...)
    {
        foreach(newElement; newElements) {
            auto result = binary_search(_elements, newElement);
            if (!result.found) {
                _elements = _elements[0 .. result.index] ~ newElement ~ _elements[result.index .. $];
            }
        }
    }

    void
    add(Set!T otherSet)
    {
        // The fact otherSet._elements is sorted enables more efficiency
        auto newElements = new T[_elements.length + otherSet._elements.length];
        size_t ne_i, this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (_elements[this_i] < otherSet._elements[os_i]) {
                newElements[ne_i++] = _elements[this_i++];
            } else if (otherSet._elements[os_i] < _elements[this_i]) {
                newElements[ne_i++] = otherSet._elements[os_i++];
            } else {
                newElements[ne_i++] = _elements[this_i++];
                os_i++;
            }
        }
        // Add the (one or less) tail if any
        while (this_i < _elements.length) {
            newElements[ne_i++] = _elements[this_i++];
        }
        while (os_i < otherSet._elements.length) {
            newElements[ne_i++] = otherSet._elements[os_i++];
        }
        _elements = newElements[0 .. ne_i].dup;
    }

    void
    remove(T[] delElements...)
    {
        foreach(delElement; delElements) {
            auto result = binary_search(_elements, delElement);
            if (result.found) {
                _elements = _elements[0 .. result.index] ~ _elements[result.index + 1 .. $];
            }
        }
    }

    void
    remove(Set!T otherSet)
    {
        // The fact otherSet._elements is sorted enables more efficiency
        auto newElements = new T[_elements.length];
        size_t ne_i, this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (_elements[this_i] < otherSet._elements[os_i]) {
                newElements[ne_i++] = _elements[this_i++];
            } else if (otherSet._elements[os_i] < _elements[this_i]) {
                os_i++;
            } else {
                this_i++;
                os_i++;
            }
        }
        while (this_i < _elements.length) {
            newElements[ne_i++] = _elements[this_i++];
        }
        _elements = newElements[0 .. ne_i].dup;
    }

    bool
    contains(T[] targetElements ...)
    {
        foreach (targetElement; targetElements) {
            if (!binary_search(_elements, targetElement).found)
                return false;
        }
        return true;
    }

    bool
    contains(Set!T otherSet)
    {
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if ((_elements.length - this_i) < (otherSet._elements.length - os_i)) {
                return false;
            } else if (_elements[this_i] < otherSet._elements[os_i]) {
                this_i++;
            } else if (otherSet._elements[os_i] < _elements[this_i]) {
                os_i++;
            } else {
                this_i++;
                os_i++;
            }
        }
        return true;
    }

    bool
    intersects(Set!T otherSet)
    {
        size_t this_i, os_i;
        while (this_i < _elements.length && os_i < otherSet._elements.length) {
            if (_elements[this_i] < otherSet._elements[os_i]) {
                this_i++;
            } else if (otherSet._elements[os_i] < _elements[this_i]) {
                os_i++;
            } else {
                return true;
            }
        }
        return false;
    }

    override bool
    opEquals(Object object)
    in {
        assert(typeof(object) == typeof(this));
    }
    body {
        return _elements == (cast(typeof(this)) object)._elements;
    }

    override string
    toString()
    {
        if (_elements.length == 0) return "Set{}";
        auto str = format("Set{%s", _elements[0]);
        foreach (element; _elements[1 .. $]) {
            str ~= format(", %s", element);
        }
        str ~= "}";
        return str; 
    }
}

Set!T set_union(T)(Set!T a, Set!T b) {
    auto union_a_b = a.clone();
    union_a_b.add(b);
    return union_a_b;
}

Set!T set_intersection(T)(Set!T a, Set!T b) {
    auto elements = new T[a._elements.length > b._elements.length ? a._elements.length : b._elements.length];
    size_t e_i, a_i, b_i;
    while (a_i < a._elements.length && b_i < b._elements.length) {
        if (a._elements[a_i] < b._elements[b_i]) {
            a_i++;
        } else if (b._elements[b_i] < a._elements[a_i]) {
            b_i++;
        } else {
            elements[e_i] = a._elements[a_i];
            e_i++;
            a_i++;
            b_i++;
        }
    }
    auto intersection_a_b = new Set!T;
    intersection_a_b._elements = elements[0 .. e_i].dup;
    return intersection_a_b;
}

unittest {
    // TODO: write a more thorough Sets unittest
    auto iset = new Set!int;
    iset.add(1, 4, 2, 4, 2);
    assert(iset.cardinality == 3);
    assert(iset.elements == [1, 2, 4]);
    auto xset = new Set!int(4, 2, 1, 4, 2);
    assert(xset.cardinality == 3);
    assert(xset == iset);
    assert(set_union(iset, xset).cardinality == 3);
    auto uset = set_union(iset, xset);
    assert(uset.cardinality == 3);
    xset.add(5);
    iset.add(7);
    assert(set_intersection(xset, iset) == uset);
    assert(iset.contains(uset));
    assert(!uset.contains(iset));
    assert(xset != iset);
    assert(uset.cardinality == 3);
    uset.add(9);
    assert(!iset.contains(9));
    assert(!xset.contains(9));
    assert(xset.contains(5));
}

unittest {
    class Dummy {
        int val;
        this(int ival) { val = ival; };
        override int
        opCmp(Object o)
        {
            return val - (cast(Dummy) o).val;
        }
    }
    Dummy[] dlist = [new Dummy(1), new Dummy(4), new Dummy(2), new Dummy(3)];
    auto dummyset = new Set!Dummy(dlist);
}

// TODO: fix this so const can be used for parameters when T not a class
private bool
strictly_ordered(T)(T[] list) {
    for (auto j = 1; j < list.length; j++) {
        if (list[j - 1] >= list[j])
            return false;
    }
    return true;
}

unittest {
    assert(strictly_ordered(new int[0]));
    assert(strictly_ordered([1]));
    assert(!strictly_ordered([1, 1]));
    assert(strictly_ordered([1, 2, 3, 4, 5, 6, 7]));
    assert(!strictly_ordered([1, 2, 4, 3, 5, 6, 7]));
    assert(!strictly_ordered([1, 2, 3, 5, 5, 6, 7]));
}

struct BinarySearchResult {
    bool found; // whether the item was found
    size_t index; // location of item if found else "insert before" point
}

// TODO: fix this so const can be used for parameters when T not a class
BinarySearchResult
binary_search(T)(T[] list, T item)
in {
    assert(strictly_ordered(list));
}
body {
    // unsigned array indices make this prudent or imax could go out of range
    if (list.length == 0 || item < list[0])
        return BinarySearchResult(false, 0);
    auto imax = list.length - 1;
    typeof(imax) imin = 0;

    while (imax >= imin) {
        typeof(imax) imid = (imin + imax) / 2;
        if (list[imid] < item) {
            imin = imid + 1;
        } else if (list[imid] > item) {
            imax = imid - 1;
        } else {
            return BinarySearchResult(true, imid);
        }
    }
    assert(imin >= imax);
    assert(imin == list.length || list[imin] > item);
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

Set!T
extract_key_set(T, G)(G[T] assocArray)
{
    return new Set!T(assocArray.keys);
}

unittest {
    auto test = [1: 2, 7 : 8, 3 : 4];
    assert(extract_key_set(test).cardinality == 3);
}
