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

// Calculates steps in data array for each index (template)
template blockSizeForDimT(dimTuple...)
{
    static if(dimTuple.length == 1)
        enum size_t[] blockSizeForDimT = [1];
    else
        enum size_t[] blockSizeForDimT = [blockSizeForDimT!(dimTuple[1..$])[0] * dimTuple[1]] //XXX
            ~ blockSizeForDimT!(dimTuple[1..$]);
}

// Calculates steps in data array for each index (function)
size_t[] blockSizeForDim(const(size_t)[] dim) pure
{
    auto result = new size_t[dim.length];
    result[$-1] = 1;
    foreach_reverse(i, d; dim[0..$-1])
        result[i] = result[i+1] * dim[i+1];
    return result;
}

struct Arrax(T, dimTuple...)
{
    //TODO: Make DataContainer some copy-on-write type
    //TODO: Add trusted, nothrough, pure, etc 
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    
    // If the size of array is dynamic
    enum isDynamic = canFind([dimTuple], 0);

    enum size_t rank = dimTuple.length;

    // Array dimensions and data contatiner type
    static if(isDynamic)
    {
        size_t[rank] dim = [dimTuple];
        size_t[rank] blockSize;
        alias T[] DataContainer;
    }
    else
    {
        enum size_t[] dim = [dimTuple];
        enum size_t[] blockSize = blockSizeForDimT!(dimTuple);
        alias T[reduce!("a * b")(dim)] DataContainer;
    }
    
    // Leading dimension
    static if(dimTuple[0] != 0)
        enum size_t length = dimTuple[0];
    else
        size_t length() { return dim[0]; }

    DataContainer _data;

    static if(isDynamic)
        void _resize(size_t newSize)
        {
            _data.length = newSize;
        }

    static if(isDynamic)
        this(T[] data_, size_t[] dim_, size_t[] blockSize_ = [])
            in
            {
                assert(dim_.length == rank);
                assert(!((blockSize_ != []) && (blockSize_.length != rank)));
                if(blockSize_ != [])
                    assert(data_.length == dim_[0] * blockSize_[0]);
                else
                    assert(data_.length == reduce!("a * b")(dim_));
            }
        body
        {
            _data = data_;
            dim = dim_;
            if(blockSize_ != [])
                blockSize = blockSize_;
            else
                blockSize = blockSizeForDim(dim);
        }
}

unittest
{
    static assert(Arrax!(int, 0).isDynamic);
    static assert(Arrax!(int, 1, 0).isDynamic);
    static assert(!(Arrax!(int, 1).isDynamic));
    static assert(!(Arrax!(int, 1, 2).isDynamic));

    static assert(Arrax!(int, 1, 2).dim == [1, 2]);
    static assert(Arrax!(int, 4, 2, 3).blockSize == [6, 3, 1]);
    static assert(Arrax!(int, 1, 2).length == 1);
    Arrax!(int, 1, 2, 0) a;
    assert(a.rank == 3);
    assert(a.dim == [1, 2, 0]);
    assert(a.length == 1);
    
    Arrax!(int, 0, 2) b;
    assert(b.length == 0);

    auto c = Arrax!(int, 0, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [2, 2, 3]);
    assert(c._data == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    assert(c.dim == [2, 2, 3]);
    assert(c.blockSize == [6, 3, 1]);
    auto d = Arrax!(int, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [2, 3], [6, 2]);
    assert(d._data == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    assert(d.dim == [2, 3]);
    assert(d.blockSize == [6, 2]);
}
