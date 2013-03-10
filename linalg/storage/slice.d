// Written in the D programming language.

module linalg.storage.slice;

struct Slice
{
    size_t lo;
    size_t up;
    size_t stride;

    this(size_t lo, size_t up)
    {
        this.lo = lo;
        this.up = up;
    }
}
