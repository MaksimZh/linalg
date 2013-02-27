// Written in the D programming language.

/** Auxiliary functions for strided view of one-dimensional array.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.storage.stride;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.storage.mdarray;

// Calculates strides in data array for dense storage
size_t[] calcDenseStrides(in size_t[] dim) pure
{
    if(dim.length == 1)
        return [1];
    else
    {
        auto tail = calcDenseStrides(dim[1..$]);
        return [dim[1] * tail[0]] ~ tail;
    }
}

unittest
{
    assert(calcDenseStrides([2, 3, 4]) == [12, 4, 1]);
    static assert(calcDenseStrides([2, 3, 4]) == [12, 4, 1]);
}

// Calculates strides in data array for transposed dense storage
size_t[] calcDenseStridesTransp(in size_t[] dim) pure
{
    if(dim.length == 1)
        return [1];
    else
    {
        auto tail = calcDenseStridesTransp(dim[0..$-1]);
        return tail ~ [dim[$-2] * tail[$-1]];
    }
}

unittest
{
    assert(calcDenseStridesTransp([2, 3, 4]) == [1, 2, 6]);
    static assert(calcDenseStridesTransp([2, 3, 4]) == [1, 2, 6]);
}

// Calculates strides in data array for dense storage
size_t[] calcDenseStrides(in size_t[] dim, bool isTransposed) pure
{
    return isTransposed ? calcDenseStridesTransp(dim) : calcDenseStrides(dim);
}

// Calculates container size for dense storage
size_t calcDenseContainerSize(in size_t[] dim) pure
{
    //TODO: Clean this when std.algorithm functions become pure
    uint result = 1;
    foreach(d; dim)
        result *= d;
    return result;
}

// Convert slice to built-in multidimensional array
auto sliceToArray(T, uint rank)(in size_t[] dim,
                                in size_t[] stride,
                                in T[] container)
    in
    {
        assert(dim.length == rank);
        assert(stride.length == rank);
    }
body
{
    static if(rank > 0)
    {
        auto result = new MultArrayType!(T, rank - 1)[dim[0]];
        foreach(i; 0..dim[0])
            result[i] =
                sliceToArray!(T, rank - 1)(dim[1..$],
                                           stride[1..$],
                                           container[(stride[0] * i)..$]);
        return result;
    }
    else
        return container[0];
}

unittest // sliceToArray
{
    assert(sliceToArray!(int, 3)([2, 3, 4], [12, 4, 1], array(iota(24)))
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
}
