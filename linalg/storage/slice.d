// Written in the D programming language.

/**
 * Helping code for slice implementation.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.storage.slice;

struct Slice
{
    const size_t lo; // lower boundary
    const size_t up; // upper boundary
    const size_t stride; // stride (1 means no gap)

    this(size_t lo, size_t up, size_t stride = 1) pure
    {
        this.lo = lo;
        this.up = up;
        this.stride = stride;
    }

    /*
     * Number of elements in slice
     * This number is not equal to length of referred array part
     * if stride is greater than 1
     */
    @property size_t length() pure
    {
        return (up - lo - 1) / stride + 1;
    }

    /* Real upper boundary in referred array with stride remainder dropped */
    @property size_t upReal() pure
    {
        return lo + (length - 1) * stride + 1;
    }
}

/* Slice overload is the same for all storages, matrices and arrays */
mixin template sliceOverload()
{
    Slice opSlice(size_t dimIndex)(size_t lo, size_t up) pure
    {
        static assert(dimIndex == 0);
        return Slice(lo, up);
    }
}
