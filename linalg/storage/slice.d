// Written in the D programming language.

module linalg.storage.slice;

struct Slice
{
    const size_t lo;
    const size_t up;
    const size_t stride;

    this(size_t lo, size_t up, size_t stride = 1)
    {
        this.lo = lo;
        this.up = up;
        this.stride = stride;
    }

    @property size_t length() pure const
    {
        return (up - lo - 1) / stride + 1;
    }

    @property size_t upReal() pure const
    {
        return lo + (length - 1) * stride + 1;
    }
}

mixin template sliceOverload()
{
    Slice opSlice(size_t dimIndex)(size_t lo, size_t up) pure const
    {
        static assert(dimIndex == 0);
        return Slice(lo, up);
    }
}
