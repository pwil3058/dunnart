module idnumber;

mixin template UniqueId(T) {
    protected static T next_id;
    const T id;

    const string set_unique_id = "id = next_id++;";

    override hash_t
    toHash()
    {
        return id;
    }

    override bool
    opEquals(Object o)
    {
        return id == (cast(typeof(this)) o).id;
    }

    override int
    opCmp(Object o)
    {
        return id - (cast(typeof(this)) o).id;
    }
}
