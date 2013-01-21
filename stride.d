// Written in the D programming language.

/** This module contains functions for strides.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module stride;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import mdarray;

// Calculates strides in data array for dense storage
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

// Calculates strides in data array for transposed dense storage
size_t[] calcDenseStridesTransp(const(size_t)[] dim) pure
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

// Copy one slice to another one with the same dimensions
void copySliceToSlice(T)(in size_t[] dim,
                         in size_t[] dstride, T[] dest,
                         in size_t[] sstride, in T[] source) pure
    in
    {
        assert(dstride.length == dim.length);
        assert(sstride.length == dim.length);
    }
body
{
    if(dim.length == 0)
        dest[0] = source[0];
    else
        foreach(i; 0..dim[0])
            copySliceToSlice(dim[1..$],
                             dstride[1..$], dest[(dstride[0]*i)..$],
                             sstride[1..$], source[(sstride[0]*i)..$]);
}

unittest // copySliceToSlice
{
    int[] source = array(iota(0, 24));
    int[] dest0 = array(iota(24, 48));
    {
        int[] dest = dest0.dup;
        copySliceToSlice([24], [1], dest, [1], source);
        assert(dest == source);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice([5], [2], dest, [3], source);
        assert(dest[0..9] == [0, 25, 3, 27, 6, 29, 9, 31, 12]);
        assert(dest[9..$] == dest0[9..$]);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice([2, 3, 4], [12, 4, 1], dest, [12, 4, 1], source);
        assert(dest == source);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice([2, 2, 2], [12, 8, 3], dest, [12, 4, 2], source[5..24]);
        assert(dest == [5, 25, 26, 7,    28, 29, 30, 31,  9, 33, 34, 11,
                        17, 37, 38, 19,  40, 41, 42, 43,  21, 45, 46, 23]);
    }
}

// Copy built-in array to slice with the same dimensions
void copyArrayToSlice(T, A)(size_t[] dim, size_t[] stride, T[] container, A a)
    in
    {
        assert(getDimensions(a) == dim);
    }
body
{
    static if(!is(typeof(a.length)))
    {
        container[0] = a;
    }
    else
    {
        // Copy elements recursively
        foreach(i; 0..dim[0])
            copyArrayToSlice(dim[1..$], stride[1..$], container[(stride[0]*i)..$], a[i]);
    }
}

unittest // copyArrayToSlice
{
    auto source = [[[0, 1, 2, 3],
                    [4, 5, 6, 7],
                    [8, 9, 10, 11]],
                   [[12, 13, 14, 15],
                    [16, 17, 18, 19],
                    [20, 21, 22, 23]]];
    auto test = array(iota(0, 24));
    int[] dest0 = array(iota(24, 48));
    {
        int[] dest = dest0.dup;
        copyArrayToSlice([2, 3, 4], [12, 4, 1], dest, source);
        assert(dest == test);
    }
}

// Compare two slices with the same dimensions
bool compareSliceSlice(T)(in size_t[] dim,
                          in size_t[] astride, in T[] a,
                          in size_t[] bstride, in T[] b) pure
    in
    {
        assert(astride.length == dim.length);
        assert(bstride.length == dim.length);
    }
body
{
    if(dim.length == 0)
        return a[0] == b[0];
    else
    {
        foreach(i; 0..dim[0])
            if(!compareSliceSlice(dim[1..$],
                                  astride[1..$], a[(astride[0]*i)..$],
                                  bstride[1..$], b[(bstride[0]*i)..$]))
                return false;
        return true;
    }
}

unittest // compareSliceSlice
{
    assert(compareSliceSlice([2, 3, 4],
                             [12, 4, 1], array(iota(0, 48, 2)),
                             [24, 8, 2], array(iota(0, 48))));
}

// Compare built-in array and slice with the same dimensions
bool compareSliceArray(T, A)(size_t[] dim, size_t[] stride, T[] container, A a)
    in
    {
        assert(getDimensions(a) == dim);
    }
body
{
    static if(!is(typeof(a.length)))
    {
        return container[0] == a;
    }
    else
    {
        if(dim[0] != a.length)
            return false;
        // Compare elements recursively
        foreach(i; 0..dim[0])
            if(!compareSliceArray(dim[1..$], stride[1..$], container[(stride[0]*i)..$], a[i]))
                return false;
        return true;
    }
}

unittest // compareSliceArray
{
    assert(compareSliceArray([2, 3, 4], [12, 4, 1], array(iota(0, 24)),
                             [[[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]],
                              [[12, 13, 14, 15],
                               [16, 17, 18, 19],
                               [20, 21, 22, 23]]]));
}
