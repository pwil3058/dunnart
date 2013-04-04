module idnumber;

mixin template Id(T) {
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
    mixin Id!(T);
    protected static T next_id;

    const string set_unique_id = "id = next_id++;";
}
