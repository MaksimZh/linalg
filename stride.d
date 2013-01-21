// Written in the D programming language.

/** This module contains functions for strides.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module stride;

// Calculates strides in data array
size_t[] calcDenseStrides(const(size_t)[] dim) pure
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