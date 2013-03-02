// Written in the D programming language.

module linalg.storage.slice;

/* Structure to store slice boundaries compactly */
struct SliceBounds
{
    const size_t lo;
    const size_t up;
    const size_t st;

    this(size_t lo_, size_t up_) pure
    {
        lo = lo_;
        up = up_;
        st = 1;
    }

    this(size_t i) pure
    {
        lo = i;
        up = i + 1;
        st = 0;
    }

    // Whether this is single index not slice
    bool isIndex() pure const
    {
        return !(st == 0);
    }
}
