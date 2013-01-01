module arrax;

import std.algorithm;

template AuxTypeValue(T, T a){}

template isValueOfType(T, v...)
{
    static if(v.length == 0)
        enum bool isValueOfType = false;
    else static if(v.length == 1)
        enum bool isValueOfType = is(typeof(AuxTypeValue!(T, v[0])));
    else
        enum bool isValueOfType = isValueOfType!(T, v[0..1]) && isValueOfType!(T, v[1..$]);
}

unittest
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

enum size_t dynamicSize = 0;

struct Arrax(T, dimTuple...)
{
    //TODO: Make DataContainer some copy-on-write type
    //TODO: Add trusted, nothrough, pure, etc 
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    
    // If the size of array is dynamic
    enum isStatic = !canFind([dimTuple], 0);

    enum size_t rank = dimTuple.length;

    // Array dimensions and data contatiner type
    static if(isStatic)
    {
        enum size_t[] dim = [dimTuple];
        alias T[reduce!("a * b")(dim)] DataContainer;
    }
    else
    {
        size_t[rank] dim = [dimTuple];
        alias T[] DataContainer;
    }
    
    // Leading dimension
    static if(dimTuple[0] != 0)
        enum size_t length = dimTuple[0];
    else
        size_t length() { return dim[0]; }

    DataContainer _data;

    static if(!isStatic)
        void _resize(size_t newSize)
        {
            _data.length = newSize;
        }
}

unittest
{
    static assert(!(Arrax!(int, 0).isStatic));
    static assert(!(Arrax!(int, 1, 0).isStatic));
    static assert(Arrax!(int, 1).isStatic);
    static assert(Arrax!(int, 1, 2).isStatic);

    static assert(Arrax!(int, 1, 2).dim == [1, 2]);
    static assert(Arrax!(int, 1, 2).length == 1);
    Arrax!(int, 1, 2, 0) a;
    assert(a.rank == 3);
    assert(a.dim == [1, 2, 0]);
    assert(a.length == 1);
    
    Arrax!(int, 0, 2) b;
    assert(b.length == 0);
}
