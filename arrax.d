// Written in the D programming language.

/** This module contains the $(LREF Arrax) .

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
/* Possible problems:

   Probably some symbol names should be replaced with better ones.
   
   Grammar and spelling should be fixed especially in comments and embedded documentation.
   
   SliceProxy evaluates to array slice.
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

impoer aux;

// Value to denote not fixed dimension of the array
enum size_t dynamicSize = 0;

// Calculates steps in data array for each index. template
template strideDenseStorageT(dimTuple...)
{
    static if(dimTuple.length == 1)
        enum size_t[] strideDenseStorageT = [1];
    else
        enum size_t[] strideDenseStorageT = [strideDenseStorageT!(dimTuple[1..$])[0] * dimTuple[1]] //XXX
            ~ strideDenseStorageT!(dimTuple[1..$]);
}

// Calculates steps in data array for each index. function
size_t[] strideDenseStorage(const(size_t)[] dim) pure
{
    auto result = new size_t[dim.length];
    result[$-1] = 1;
    foreach_reverse(i, d; dim[0..$-1])
        result[i] = result[i+1] * dim[i+1];
    return result;
}

// Copy one slice to another one with the same dimensions
void copySliceToSlice(T)(T[] dest, in size_t[] dstride,
                         in T[] source, in size_t[] sstride,
                         in size_t[] dim)
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

/* Multidimensional array slice.
   Unlike arrays slices do not perform memory management.
   Their dimensions and stride of slice are calculated only once
   and can not be changed.
   Currently they are used only for data copying.
   Support of other operations (like arithmetic) is planned.
   For other procedures they should be converted to dense arrays.
 */
struct ArraxSlice(T, uint rank)
{
}

/*
  Multidimensional array.
 */
struct ArraxDense(T, dimTuple...)
{
    //TODO: Make ContainerType some copy-on-write type
    //TODO: Add trusted, nothrough, pure, etc
    //FIXME: Some members should be private
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    
    // If the size of array is dynamic (i.e. at least one dimension is not defined)
    enum isDynamic = canFind([dimTuple], dynamicSize);

    enum size_t rank = dimTuple.length;

    // Array dimensions stride and data container type
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
        // Change the size of the container
        private void _resize(size_t newSize)
        {
            _container.length = newSize;
        }

    static if(isDynamic)
        // Convert ordinary 1D array to dynamic MD array with given dimensions and strides
        this(T[] source, size_t[] dim_, size_t[] stride_ = [])
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
                    assert(source.length == requiredSize);
                }
                else
                    assert(source.length == reduce!("a * b")(dim_));
                foreach(i, d; dimTuple)
                    if(d != dynamicSize)
                        assert(d == dim_[i]);
            }
        body
        {
            _container = source;
            _dim = dim_;
            // If strides are not specified create a dense array
            if(stride_ != [])
                _stride = stride_;
            else
                _stride = strideDenseStorage(_dim);
        }
    else
        // Convert ordinary 1D array to static MD array with dense storage (no stride)
        this(T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _container = source;
        }

    // Compare with a jagged array (btw. always false if really jagged)
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
    ref Arrax opAssign(Arrax source)
    {
        static if(isDynamic)
        {
            _dim = source._dim.dup;
            _stride = source._stride.dup;
            _container = source._container; //FIXME: may be wrong depending on COW approach we choose
        }
        else
            _container = source._container.dup;
        return this;
    }

    // Auxiliary structure for slicing and indexing
    struct SliceProxy(size_t sliceRank, size_t depth)
    {
        // Type of the array that corresponds to the slicing result
        static if(sliceRank > 0)
            alias Arrax!(T, manyDynamicSize!(sliceRank)) EvalType;
        else
            alias T EvalType; // Slice is just set of indices
        
        //TODO: dynamic array is not an optimal solution
        SliceBounds[] bounds;

        // Pointer to the array for which slice is calculated
        Arrax* source;

        this(Arrax* source_, SliceBounds[] bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        // Calculate slice dimensions, strides and position in the container
        void sliceParams(out size_t[] dim,  // Dimensions of the resulting array
                         out size_t[] stride,  // Strides of the resulting array
                         out size_t bndLo,  // Lower boundary in the container
                         out size_t bndUp)  // Upper boundary in the container
        {
            dim = [];
            stride = [];
            bndLo = 0;
            bndUp = 0;

            /* Dimensions and strides should be copied for all regular slices
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
        }

        // Calculate slice position in the container
        size_t sliceStart()
        {
            size_t index = 0; // Position in the container
            foreach(i, b; bounds)
                index += source._stride[i] * b.lo;
            return index;
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
                    
                    size_t[] dim;
                    size_t[] stride;
                    size_t bndLo;
                    size_t bndUp;

                    sliceParams(dim, stride, bndLo, bndUp);
            
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
                    
                    size_t index = sliceStart();
                    
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
    alias Arrax!(int, 0, 3, 0) A1;
    A1 a1, b1;
    a1 = A1(array(iota(0, 24)), [2, 3, 4]);
    assert((b1 = a1) == test);
    assert(b1 == test);
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
