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
