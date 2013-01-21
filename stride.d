// Written in the D programming language.

/** This module contains functions for strides.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module stride;

version(unittest)
{
    import std.array;
    import std.range;
}

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
void copySliceToSlice(T)(T[] dest, in size_t[] dstride,
                         in T[] source, in size_t[] sstride,
                         in size_t[] dim) pure
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
            copySliceToSlice(dest[(dstride[0]*i)..$], dstride[1..$],
                             source[(sstride[0]*i)..$], sstride[1..$],
                             dim[1..$]);
}

unittest // copySliceToSlice
{
    int[] source = array(iota(0, 24));
    int[] dest0 = array(iota(24, 48));
    {
        int[] dest = dest0.dup;
        copySliceToSlice(dest, [1], source, [1], [24]);
        assert(dest == source);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice(dest, [2], source, [3], [5]);
        assert(dest[0..9] == [0, 25, 3, 27, 6, 29, 9, 31, 12]);
        assert(dest[9..$] == dest0[9..$]);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice(dest, [12, 4, 1], source, [12, 4, 1], [2, 3, 4]);
        assert(dest == source);
    }
    {
        int[] dest = dest0.dup;
        copySliceToSlice(dest, [12, 8, 3], source[5..24], [12, 4, 2], [2, 2, 2]);
        assert(dest == [5, 25, 26, 7,    28, 29, 30, 31,  9, 33, 34, 11,
                        17, 37, 38, 19,  40, 41, 42, 43,  21, 45, 46, 23]);
    }
}

// Copy built-in array to slice with the same dimensions
void copyArrayToSlice(T, A)(T[] container, size_t[] dim, size_t[] stride, A a)
{
    static if(!is(typeof(a.length)))
    {
        container[0] = a;
    }
    else
    {
        // Copy elements recursively
        foreach(i; 0..dim[0])
            copyArrayToSlice(container[(stride[0]*i)..$], dim[1..$], stride[1..$], a[i]);
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
        copyArrayToSlice(dest, [2, 3, 4], [12, 4, 1], source);
        assert(dest == test);
    }
}

// Compare built-in array and slice with the same dimensions
bool compareSliceArray(T, A)(T[] container, size_t[] dim, size_t[] stride, A a)
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
            if(!compareSliceArray(container[(stride[0]*i)..$], dim[1..$], stride[1..$], a[i]))
                return false;
        return true;
    }
}

unittest // compareSliceArray
{
    assert(compareSliceArray(array(iota(0, 24)), [2, 3, 4], [12, 4, 1],
                             [[[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]],
                              [[12, 13, 14, 15],
                               [16, 17, 18, 19],
                               [20, 21, 22, 23]]]));
}
