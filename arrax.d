module arrax;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

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
        alias DataContainer DataContainerDynamic;
    }
    else
    {
        enum size_t[] dim = [dimTuple];
        enum size_t[] blockSize = blockSizeForDimT!(dimTuple);
        alias T[reduce!("a * b")(dim)] DataContainer;
        alias T[] DataContainerDynamic;
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
                {
                    size_t requiredSize = 0;
                    foreach(i, d; dim_)
                        requiredSize += blockSize_[i] * (dim_[i] - 1);
                    ++requiredSize;
                    assert(data_.length == requiredSize);
                }
                else
                    assert(data_.length == reduce!("a * b")(dim_));
                foreach(i, d; dimTuple)
                    if(d) assert(d == dim[i]);
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
    else
        this(T[] data_)
            in
            {
                assert(data_.length == reduce!("a * b")(dim));
            }
        body
        {
            _data = data_;
        }

    bool opEquals(MultArrayType!(T, rank) a)
    {
        if(length != a.length)
            return false;
        foreach(i; 0..length)
            if(this[i].eval() != a[i])
                return false;
        return true;
    }
        
    struct SliceProxy(size_t sliceRank, size_t depth)
    {
        //TODO: dynamic array is not an optimal solution
        SliceBounds[] bounds;

        Arrax source;

        this(ref Arrax source_, SliceBounds[] bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        // Evaluate array for the slice
        static if(depth < rank)
        {
            // If there is not enough bracket pairs - add empty []
            Arrax!(T, manyDynamicSize!(sliceRank)) eval()
            {
                return this[].eval;
            }
        }
        else
        {
            static if(sliceRank > 0)
                Arrax!(T, manyDynamicSize!(sliceRank)) eval()
                {
                    size_t[] dim = [];
                    size_t[] blockSize = [];
                    size_t dataLo = 0;
                    size_t dataUp = 0;
                    foreach(i, b; bounds)
                    {
                        dataLo += source.blockSize[i] * b.lo;
                        if(b.isRegularSlice)
                        {
                            dataUp += source.blockSize[i] * (b.up - 1);
                            dim ~= b.up - b.lo;
                            blockSize ~= source.blockSize[i];
                        }
                        else
                            dataUp += source.blockSize[i] * b.up;
                    }
                    ++dataUp;
            
                    debug(slices)
                    {
                        writeln("Arrax.SliceProxy.eval(<slice>):");
                        writeln("    dim = ", dim);
                        writeln("    blockSize = ", blockSize);
                        writeln("    data[", dataLo, "..", dataUp, "]");
                    }

                    return typeof(return)(source._data[dataLo..dataUp], dim, blockSize);
                }
            else
                T eval()
                {
                    size_t dataLo = 0;
                    foreach(i, b; bounds)
                        dataLo += source.blockSize[i] * b.lo;
                
                    debug(slices)
                    {
                        writeln("Arrax.SliceProxy.eval(<index>):");
                        writeln("    data[", dataLo, "]");
                    }
                
                    return source._data[dataLo];
                }
        }

        static if(depth < dimTuple.length)
        {
            SliceProxy!(sliceRank, depth + 1) opSlice()
            {
                debug(slices)
                {
                    writeln("Arrax.SliceProxy.opSlice():");
                    writeln("    ", typeof(return).stringof);
                    writeln("    ", bounds ~ SliceBounds(0, source.dim[depth]));
                }
                return typeof(return)(source, bounds ~ SliceBounds(0, source.dim[depth]));
            }

            SliceProxy!(sliceRank, depth + 1) opSlice(size_t lo, size_t up)
            {
                debug(slices)
                {
                    writeln("Arrax.SliceProxy.opSlice(lo, up):");
                    writeln("    ", typeof(return).stringof);
                    writeln("    ", bounds ~ SliceBounds(lo, up));
                }
                return typeof(return)(source, bounds ~ SliceBounds(lo, up));
            }

            SliceProxy!(sliceRank - 1, depth + 1) opIndex(size_t i)
            {
                debug(slices)
                {
                    writeln("Arrax.SliceProxy.opIndex(i):");
                    writeln("    ", typeof(return).stringof);
                    writeln("    ", bounds ~ SliceBounds(i));
                }
                return typeof(return)(source, bounds ~ SliceBounds(i));
            }
        }
    }

    SliceProxy!(rank, 1) opSlice()
    {
        debug(slices)
        {
            writeln("Arrax.opSlice():");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(0, dim[0]));
        }
        return typeof(return)(this, [SliceBounds(0, dim[0])]);
    }

    SliceProxy!(rank, 1) opSlice(size_t lo, size_t up)
    {
        debug(slices)
        {
            writeln("Arrax.opSlice(lo, up):");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(lo, up));
        }
        return typeof(return)(this, [SliceBounds(lo, up)]);
    }

    SliceProxy!(rank - 1, 1) opIndex(size_t i)
    {
        debug(slices)
        {
            writeln("Arrax.opIndex(i):");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(i));
        }
        return typeof(return)(this, [SliceBounds(i)]);
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
    auto d = Arrax!(int, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [2, 3], [6, 2]);
    assert(d._data == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert(d.dim == [2, 3]);
    assert(d.blockSize == [6, 2]);
}

struct SliceBounds
{
    size_t lo;
    size_t up;

    this(size_t lo_, size_t up_)
    {
        lo = lo_;
        up = up_;
    }
    
    this(size_t i)
    {
        lo = i;
        up = i;
    }

    // Whether this is regular slice or index
    bool isRegularSlice()
    {
        return !(lo == up);
    }
}

template Tuple(E...)
{
    alias E Tuple;
}
    
template manyDynamicSize(size_t N)
{
    static if(N > 1)
        alias Tuple!(dynamicSize, manyDynamicSize!(N - 1)) manyDynamicSize;
    else
        alias Tuple!(dynamicSize) manyDynamicSize;
}

template MultArrayType(T, size_t N)
{
    static if(N > 0)
        alias MultArrayType!(T, N-1)[] MultArrayType;
    else
        alias T MultArrayType;
}

unittest
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(0, 24)));
    with(a[][][].eval())
    {
        assert(dim == [2, 3, 4]);
        assert(blockSize == [12, 4, 1]);
        assert(_data == a._data);
    }
    with(a[][][1].eval())
    {
        assert(dim == [2, 3]);
        assert(blockSize == [12, 4]);
        assert(_data == a._data[1..$-2]);
    }
    with(a[][][1..2].eval())
    {
        assert(dim == [2, 3, 1]);
        assert(blockSize == [12, 4, 1]);
        assert(_data == a._data[1..$-2]);
    }
    with(a[][1][].eval())
    {
        assert(dim == [2, 4]);
        assert(blockSize == [12, 1]);
        assert(_data == a._data[4..$-4]);
    }
    with(a[1][][].eval())
    {
        assert(dim == [3, 4]);
        assert(blockSize == [4, 1]);
        assert(_data == a._data[12..$]);
    }
}