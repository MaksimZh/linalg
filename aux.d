// Written in the D programming language.
module aux;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

template AuxTypeValue(T, T a){}

// Check whether the tuple is a tuple of values that can be implicitly converted to given type
template isValueOfType(T, v...)
{
    static if(v.length == 0)
        enum bool isValueOfType = false;
    else static if(v.length == 1)
        enum bool isValueOfType = is(typeof(AuxTypeValue!(T, v[0])));
    else
        enum bool isValueOfType = isValueOfType!(T, v[0..1]) && isValueOfType!(T, v[1..$]);
}

unittest // isValueOfType
{
    static assert(!isValueOfType!(ulong));
    static assert(!isValueOfType!(ulong, int));
    static assert(!isValueOfType!(ulong, 1.));
    static assert(!isValueOfType!(ulong, 1, int));
    static assert(!isValueOfType!(ulong, 1, 1.));
    static assert(isValueOfType!(float, 1.));
    static assert(isValueOfType!(float, 1, 1.));
    static assert(isValueOfType!(ulong, 1));
    static assert(isValueOfType!(ulong, 1, 2));
}

// Auxiliary tuple
template Tuple(E...)
{
    alias E Tuple;
}

// Repeat some tuple N times
template repeatTuple(size_t N, tuple...)
{
    static if(N > 1)
        alias Tuple!(tuple, repeatTuple!(N - 1, tuple)) repeatTuple;
    else
        alias Tuple!(tuple) repeatTuple;
}

unittest
{
    
}

// Type of multidimensional jagged array
template MultArrayType(T, size_t N)
{
    static if(N > 0)
        alias MultArrayType!(T, N-1)[] MultArrayType;
    else
        alias T MultArrayType;
}
