// Written in the D programming language.

/** Functions used to connect compact arrays and built-in jagged arrays.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.mdarray;

// Type of multidimensional jagged array
template MultArrayType(T, size_t N)
{
    static if(N > 0)
        alias MultArrayType!(T, N-1)[] MultArrayType;
    else
        alias T MultArrayType;
}

version(none) //XXX: Temporary not needed
{
// Test whether given array is not really jagged.
bool isHomogeneous(A)(in A a) pure
{
    static if(is(typeof(a[0].length)))
    {
        size_t len = a[0].length;
        foreach(row; a)
            if((row.length != len) || !isHomogeneous(row))
                return false;
    }
    return true;
}

unittest // isHomogeneous
{
    assert(isHomogeneous([0, 0]));
    assert(isHomogeneous([[0, 0], [0, 0]]));
    assert(!isHomogeneous([[0, 0], [0, 0, 0]]));
}

// Get dimensions of a homogeneous array.
size_t[] getHomogeneousDim(A)(in A a) pure
{
    static if(is(typeof(a.length)))
        return [a.length] ~ getHomogeneousDim(a[0]);
    else
        return [];
}

unittest // getHomogeneousDim
{
    assert(getHomogeneousDim([0]) == [1]);
    assert(getHomogeneousDim([[0, 0], [0, 0], [0, 0]]) == [3, 2]);
}

size_t[] getDimensions(A)(in A a) pure
{
    if(isHomogeneous(a))
        return getHomogeneousDim(a);
    else
        return [];
}

unittest // getDimensions
{
    assert(getDimensions(0) == []);
    assert(getDimensions([0]) == [1]);
    assert(getDimensions([[0, 0], [0, 0], [0, 0]]) == [3, 2]);
    assert(getDimensions([[0, 0], [0, 0], [0, 0, 0]]) == []);
}
}