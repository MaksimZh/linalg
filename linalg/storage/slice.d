// Written in the D programming language.

module linalg.storage.slice;

struct Slice
{
    const size_t lo;
    const size_t up;
    //const size_t stride; //TODO: when strides become part of D

    this(size_t lo, size_t up)
    {
        this.lo = lo;
        this.up = up;
    }

    @property size_t length() pure const
    {
        return up - lo;
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
