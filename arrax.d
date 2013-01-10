// Written in the D programming language.

/** This module contains the $(LREF Arrax) .

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
/* Possible problems

   Probably some symbol names should be replaced with better ones.
   
   Grammar and spelling should be fixed especially in comments and embedded documentation.
   
   SliceProxy evaluates to strided array.
   Copy on write technique may require copying values densely to another container.
   This is hard to organize if COW is implemented on container level.
 */
module arrax;

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

// Value to denote not fixed dimension of the array
enum size_t dynamicSize = 0;

// Calculates steps in data array for each index (template)
template strideDenseStorageT(dimTuple...)
{
    static if(dimTuple.length == 1)
        enum size_t[] strideDenseStorageT = [1];
    else
        enum size_t[] strideDenseStorageT = [strideDenseStorageT!(dimTuple[1..$])[0] * dimTuple[1]] //XXX
            ~ strideDenseStorageT!(dimTuple[1..$]);
}

// Calculates steps in data array for each index (function)
size_t[] strideDenseStorage(const(size_t)[] dim) pure
{
    auto result = new size_t[dim.length];
    result[$-1] = 1;
    foreach_reverse(i, d; dim[0..$-1])
        result[i] = result[i+1] * dim[i+1];
    return result;
}

struct Arrax(T, dimTuple...)
{
    //TODO: Make ContainerType some copy-on-write type
    //TODO: Add trusted, nothrough, pure, etc
    //FIXME: Some members should be private
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    
    // If the size of array is dynamic (i.e. at least one dimension is not defined)
    enum isDynamic = canFind([dimTuple], 0);

    enum size_t rank = dimTuple.length;

    // Array dimensions stride and data contatiner type
    static if(isDynamic)
    {
        private size_t[rank] _dim = [dimTuple];
        private size_t[rank] _stride;
        alias T[] ContainerType;
    }
    else
    {
        private enum size_t[] _dim = [dimTuple];
        private enum size_t[] _stride = strideDenseStorageT!(dimTuple);
        alias T[reduce!("a * b")(_dim)] ContainerType;
    }

    // Data container
    private ContainerType _container;

    // Leading dimension
    static if(dimTuple[0] != dynamicSize)
        enum size_t length = dimTuple[0];
    else
        size_t length() { return _dim[0]; }
    
    static if(isDynamic)
        // Change the size of the contatiner
        private void _resize(size_t newSize)
        {
            _container.length = newSize;
        }

    static if(isDynamic)
        // Convert ordinary 1D array to dynamic MD array with given dimensions and strides
        this(T[] src, size_t[] dim_, size_t[] stride_ = [])
            in
            {
                assert(dim_.length == rank);
                assert(!((stride_ != []) && (stride_.length != rank)));
                if(stride_ != [])
                {
                    size_t requiredSize = 0;
                    foreach(i, d; dim_)
                        requiredSize += stride_[i] * (dim_[i] - 1);
                    ++requiredSize;
                    assert(src.length == requiredSize);
                }
                else
                    assert(src.length == reduce!("a * b")(dim_));
                foreach(i, d; dimTuple)
                    if(d != dynamicSize)
                        assert(d == dim_[i]);
            }
        body
        {
            _container = src;
            _dim = dim_;
            // If strides are not specified create a dense array
            if(stride_ != [])
                _stride = stride_;
            else
                _stride = strideDenseStorage(_dim);
        }
    else
        // Convert ordinary 1D array to static MD array with dense storage (no stride)
        this(T[] src)
            in
            {
                assert(src.length == reduce!("a * b")(_dim));
            }
        body
        {
            _container = src;
        }

    // Compare with a jagged array (btw. always false if realy jagged)
    bool opEquals(MultArrayType!(T, rank) a)
    {
        if(length != a.length)
            return false;
        // Compare subelements recursively
        foreach(i; 0..length)
            if(this[i].eval() != a[i]) //FIXME: is eval() really needed here?
                return false;
        return true;
    }

    // Copy another array of the same type (rank and static dimensions must match)
    ref Arrax opAssign(Arrax src)
    {
        static if(isDynamic)
        {
            _dim = src._dim.dup;
            _stride = src._stride.dup;
        }
        _container = src._container.dup;
        return this;
    }

    // Auxilary structure for slicing and indexing
    struct SliceProxy(size_t sliceRank, size_t depth)
    {
        // Type of the array that corresponds to the slicing result
        static if(sliceRank > 0)
            alias Arrax!(T, manyDynamicSize!(sliceRank)) EvalType;
        else
            alias T EvalType; // Slice is just set of indices
        
        //TODO: dynamic array is not an optimal solution
        SliceBounds[] bounds;

        // Pointer to the array for wich slice is calculated
        Arrax* source;

        this(Arrax* source_, SliceBounds[] bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        // Evaluate array for the slice
        static if(depth < rank)
        {
            // If there is not enough bracket pairs - add empty []
            EvalType eval()
            {
                return this[].eval;
            }
        }
        else
        {
            EvalType eval()
            {
                static if(sliceRank > 0)
                {
                    // Normal slice
                    
                    size_t[] dim = []; // Dimensions of the resulting array
                    size_t[] stride = []; // Strides of the resulting array
                    size_t bndLo = 0; // Lower boundary in the contatiner
                    size_t bndUp = 0; // Upper boundary in the contatiner

                    /* Dimensions and strides shoud be copied for all regular slices
                       and omitted for indices.
                       Boundaries should not cover additional elements.
                     */
                    foreach(i, b; bounds)
                    {
                        bndLo += source._stride[i] * b.lo;
                        if(b.isRegularSlice)
                        {
                            bndUp += source._stride[i] * (b.up - 1);
                            dim ~= b.up - b.lo;
                            stride ~= source._stride[i];
                        }
                        else
                            bndUp += source._stride[i] * b.up;
                    }
                    ++bndUp;
            
                    debug(slices)
                    {
                        writeln("Arrax.SliceProxy.eval(<slice>):");
                        writeln("    dim = ", dim);
                        writeln("    stride = ", stride);
                        writeln("    _container[", bndLo, "..", bndUp, "]");
                    }

                    return EvalType(source._container[bndLo..bndUp], dim, stride);
                }
                else
                {
                    // Set of indices
                    
                    size_t index = 0; // Position in the contatiner
                    
                    foreach(i, b; bounds)
                        index += source._stride[i] * b.lo;
                
                    debug(slices)
                    {
                        writeln("Arrax.SliceProxy.eval(<index>):");
                        writeln("    _container[", index, "]");
                    }
                
                    return source._container[index];
                }
            }
        }

        alias eval this;

        // Slicing and indexing
        static if(depth < dimTuple.length)
        {
            SliceProxy!(sliceRank, depth + 1) opSlice()
            {
                debug(slices)
                {
                    writeln("Arrax.SliceProxy.opSlice():");
                    writeln("    ", typeof(return).stringof);
                    writeln("    ", bounds ~ SliceBounds(0, source._dim[depth]));
                }
                return typeof(return)(source, bounds ~ SliceBounds(0, source._dim[depth]));
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

    // Slicing and indexing
    SliceProxy!(rank, 1) opSlice()
    {
        debug(slices)
        {
            writeln("Arrax.opSlice():");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(0, _dim[0]));
        }
        return typeof(return)(&this, [SliceBounds(0, _dim[0])]);
    }

    //ditto
    SliceProxy!(rank, 1) opSlice(size_t lo, size_t up)
    {
        debug(slices)
        {
            writeln("Arrax.opSlice(lo, up):");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(lo, up));
        }
        return typeof(return)(&this, [SliceBounds(lo, up)]);
    }

    //ditto
    SliceProxy!(rank - 1, 1) opIndex(size_t i)
    {
        debug(slices)
        {
            writeln("Arrax.opIndex(i):");
            writeln("    ", typeof(return).stringof);
            writeln("    ", SliceBounds(i));
        }
        return typeof(return)(&this, [SliceBounds(i)]);
    }
}

unittest // Type properties and dimensions
{
    static assert(Arrax!(int, 0).isDynamic);
    static assert(Arrax!(int, 1, 0).isDynamic);
    static assert(!(Arrax!(int, 1).isDynamic));
    static assert(!(Arrax!(int, 1, 2).isDynamic));

    static assert(Arrax!(int, 1, 2)._dim == [1, 2]);
    static assert(Arrax!(int, 4, 2, 3)._stride == [6, 3, 1]);
    static assert(Arrax!(int, 1, 2).length == 1);
    Arrax!(int, 1, 2, 0) a;
    assert(a.rank == 3);
    assert(a._dim == [1, 2, 0]);
    assert(a.length == 1);
    
    Arrax!(int, 0, 2) b;
    assert(b.length == 0);

    auto c = Arrax!(int, 0, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [2, 2, 3]);
    assert(c._container == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    assert(c._dim == [2, 2, 3]);
    assert(c._stride == [6, 3, 1]);
    auto d = Arrax!(int, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [2, 3], [6, 2]);
    assert(d._container == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert(d._dim == [2, 3]);
    assert(d._stride == [6, 2]);
}

// Structure to store slice boundaries compactly
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

// Auxilary tuple
template Tuple(E...)
{
    alias E Tuple;
}

// Tuple of multiple dynamicSize values
template manyDynamicSize(size_t N)
{
    static if(N > 1)
        alias Tuple!(dynamicSize, manyDynamicSize!(N - 1)) manyDynamicSize;
    else
        alias Tuple!(dynamicSize) manyDynamicSize;
}

// Type of multidimensional jagged array
template MultArrayType(T, size_t N)
{
    static if(N > 0)
        alias MultArrayType!(T, N-1)[] MultArrayType;
    else
        alias T MultArrayType;
}

unittest // Comparison
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(0, 24)));
    assert(a == [[[0, 1, 2, 3],
                  [4, 5, 6, 7],
                  [8, 9, 10, 11]],
                 [[12, 13, 14, 15],
                  [16, 17, 18, 19],
                  [20, 21, 22, 23]]]);
    assert(!(a == [[[0, 1, 2, 3],
                    [4, 5, 6, 7],
                    [8, 9, 10, 11]],
                   [[12, 0, 14, 15],
                    [16, 17, 18, 19],
                    [20, 21, 22, 23]]]));
}

unittest // Assignment
{
    alias Arrax!(int, 2, 3, 4) A;
    A a, b;
    a = A(array(iota(0, 24)));
    auto test = [[[0, 1, 2, 3],
                  [4, 5, 6, 7],
                  [8, 9, 10, 11]],
                 [[12, 13, 14, 15],
                  [16, 17, 18, 19],
                  [20, 21, 22, 23]]];
    assert((b = a) == test);
    assert(b == test);
}

unittest // Slicing
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(0, 24)));
    assert(a[][][] == [[[0, 1, 2, 3],
                        [4, 5, 6, 7],
                        [8, 9, 10, 11]],
                       [[12, 13, 14, 15],
                        [16, 17, 18, 19],
                        [20, 21, 22, 23]]]);
    assert(a[][][1] == [[1, 5, 9],
                        [13, 17, 21]]);
    assert(a[][][1..3] == [[[1, 2],
                            [5, 6],
                            [9, 10]],
                           [[13, 14],
                            [17, 18],
                            [21, 22]]]);
    assert(a[][1][] == [[4, 5, 6, 7],
                        [16, 17, 18, 19]]);
    assert(a[][1][1] == [5, 17]);
    assert(a[][1][1..3] == [[5, 6],
                            [17, 18]]);
    assert(a[][1..3][] == [[[4, 5, 6, 7],
                            [8, 9, 10, 11]],
                           [[16, 17, 18, 19],
                            [20, 21, 22, 23]]]);
    assert(a[][1..3][1] == [[5, 9],
                            [17, 21]]);
    assert(a[][1..3][1..3] == [[[5, 6],
                                [9, 10]],
                               [[17, 18],
                                [21, 22]]]);
    assert(a[1][][] == [[12, 13, 14, 15],
                        [16, 17, 18, 19],
                        [20, 21, 22, 23]]);
    assert(a[1][][1] == [13, 17, 21]);
    assert(a[1][][1..3] == [[13, 14],
                            [17, 18],
                            [21, 22]]);
    assert(a[1][1][] == [16, 17, 18, 19]);
    assert(a[1][1][1] == 17);
    assert(a[1][1][1..3] == [17, 18]);
    assert(a[1][1..3][] == [[16, 17, 18, 19],
                            [20, 21, 22, 23]]);
    assert(a[1][1..3][1] == [17, 21]);
    assert(a[1][1..3][1..3] == [[17, 18],
                                [21, 22]]);
}
