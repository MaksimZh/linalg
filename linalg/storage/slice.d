// Written in the D programming language.

module linalg.storage.slice;

/* Structure to store slice boundaries compactly */
struct SliceBounds
{
    size_t lo;
    size_t up;

    this(size_t lo_, size_t up_)
    {
        lo = lo_;
        up = up_;
    }

    this(size_t i)
    {
        lo = i;
        up = i;
    }

    // Whether this is single index not slice
    bool isIndex() pure const
    {
        return !(lo == up);
    }
}
