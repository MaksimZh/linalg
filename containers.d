// Written in the D programming language.

/** Arrays and matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module containers;

import std.algorithm;

version(unittest)
{
    import std.array;
    import std.range;
}

import aux;
import mdarray;
import stride;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor,   /// [0][0][0], ..., [0][0][N], [0][1][0], ...
    columnMajor /// [0][0][0], ..., [N][0][0], [0][1][0], ...
}

/** Type of the storage */
enum StorageType
{
    fixed, /// static array
    dynamic, /// dynamic array
    resizeable /// dynamic array with memory management
}

/* Storage and dimension management for arrays and matrices */
mixin template storage(T, alias dimPattern,
                       StorageType storageType,
                       StorageOrder storageOrder)
{
    static assert(is(typeof(dimPattern[0]) : size_t));

    alias T ElementType; // Type of the array elements
    public enum uint rank = dimPattern.length; // Number of dimensions

    /* dimensions, strides and data */
    private static if(storageType == StorageType.fixed)
    {
        enum size_t[] _dim = dimPattern;
        enum size_t[] _stride =
            calcDenseStrides(_dim, storageOrder == StorageOrder.columnMajor);
        ElementType[calcDenseContainerSize(_dim)] _data;
    }
    else
    {
        size_t[rank] _dim = dimPattern;
        size_t[rank] _stride;
        ElementType[] _data;
    }

    /* Leading dimension */
    static if(dimPattern[0] != dynamicSize)
        public enum size_t length = dimPattern[0];
    else
        public size_t length() { return _dim[0]; }

    /* Full dimensions array */
    static if(storageType == StorageType.fixed)
        public enum size_t[rank] dimensions = _dim;
    else
        public @property size_t[rank] dimensions() pure const { return _dim; }

    /* Test dimensions for compatibility */
    bool isCompatibleDimensions(in size_t[] dim) pure
    {
        static if(storageType == StorageType.resizeable)
        {
            if(dim.length != rank)
                return false;
            foreach(i, d; dim)
                if((d != dimPattern[i]) && (dimPattern[i] != dynamicSize))
                    return false;
            return true;
        }
        else
        {
            return dim == _dim;
        }
    }

    /* Change dimensions */
    static if(storageType == StorageType.resizeable)
    {
        /* Recalculate strides and reallocate container for current dimensions
         */
        private void _resize() pure
        {
            _stride = calcDenseStrides(
                _dim, storageOrder == StorageOrder.columnMajor);
            _data.length = calcDenseContainerSize(_dim);
        }

        /* Change dynamic array dimensions.
           Dimensions passed to the function must be compatible.
         */
        void setAllDimensions(in size_t[] dim) pure
            in
            {
                assert(dim.length == rank);
                assert(isCompatibleDimensions(dim));
            }
        body
        {
            _dim = dim;
            _resize();
        }

        /* Change dynamic array dimensions
           Number of parameters must coincide with number of dynamic dimensions
         */
        void setDimensions(in size_t[] dim...) pure
            in
            {
                assert(dim.length == count(dimPattern, dynamicSize));
            }
        body
        {
            uint i = 0;
            foreach(d; dim)
            {
                while(dimPattern[i] != dynamicSize) ++i;
                _dim[i] = d;
                ++i;
            }
            _resize();
        }
    }
}

/** Detect whether A has storage mixin inside */
template isStorage(A)
{
    enum bool isStorage = is(typeof(()
        {
            A a;
            static assert(is(typeof(A.rank) == uint));
            static assert(is(typeof(a._dim)));
            static assert(is(typeof(a._dim[0]) == size_t));
            static assert(is(typeof(a._stride)));
            static assert(is(typeof(a._stride[0]) == size_t));
            static assert(is(typeof(a._data)));
            //XXX: DMD issue 9424
            //static assert(is(typeof(a._data[0]) == A.ElementType));
        }));
}

/* Structure to store slice boundaries compactly */
private struct SliceBounds
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

/* Slicing and indexing management for arrays and matrices */
mixin template sliceProxy(SourceType, alias constructSlice)
{
    /* Auxiliary structure for slicing and indexing */
    struct SliceProxy(size_t sliceRank, size_t sliceDepth)
    {
        SliceBounds[] bounds; //FIXME: dynamic array is not an optimal solution

        SourceType* source; // Pointer to the container being sliced

        private this(SourceType* source_, SliceBounds[] bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        /* Evaluate slicing result */
        static if(sliceRank > 0)
        {
            auto eval()
            {
                static if(sliceDepth < rank)
                {
                    /* If there is not enough bracket pairs - add empty [] */
                    static if(sliceDepth == rank - 1)
                        return this[];
                    else
                        return this[].eval();
                }
                else
                {
                    /* Normal slice */
                    return constructSlice!(sliceRank)(source, bounds);
                }
            }
        }
        else
        {
            /* If simple index return element by reference */
            ref auto eval()
            {
                size_t index = 0; // Position in the container
                foreach(i, b; bounds)
                    index += source._stride[i] * b.lo;
                return source._data[index];
            }
        }

        /* Slicing and indexing */
        static if(sliceDepth < dimPattern.length - 1)
        {
            /* Return slice proxy for incomplete bracket construction
            */
            SliceProxy!(sliceRank, sliceDepth + 1) opSlice()
            {
                return typeof(return)(
                    source, bounds ~ SliceBounds(0, source._dim[sliceDepth]));
            }

            SliceProxy!(sliceRank, sliceDepth + 1) opSlice(size_t lo, size_t up)
            {
                return typeof(return)(source, bounds ~ SliceBounds(lo, up));
            }

            SliceProxy!(sliceRank - 1, sliceDepth + 1) opIndex(size_t i)
            {
                return typeof(return)(source, bounds ~ SliceBounds(i));
            }
        }
        else static if(sliceDepth == (dimPattern.length - 1))
             {
                 /* If only one more slicing can be done
                    then return slice not proxy
                 */
                 auto opSlice()
                 {
                     return SliceProxy!(sliceRank, sliceDepth + 1)(
                         source,
                         bounds ~ SliceBounds(0, source._dim[sliceDepth])
                         ).eval();
                 }

                 auto opSlice(size_t lo, size_t up)
                 {
                     return SliceProxy!(sliceRank, sliceDepth + 1)(
                         source, bounds ~ SliceBounds(lo, up)).eval();
                 }

                 static if(sliceRank > 1)
                 {
                     auto opIndex(size_t i)
                     {
                         return SliceProxy!(sliceRank - 1, sliceDepth + 1)(
                             source, bounds ~ SliceBounds(i)).eval();
                     }
                 }
                 else
                 {
                     /* If simple index return element by reference */
                     ref auto opIndex(size_t i)
                     {
                         return SliceProxy!(sliceRank - 1, sliceDepth + 1)(
                             source, bounds ~ SliceBounds(i)).eval();
                     }
                 }
             }

        auto opCast(Tresult)()
        {
            return cast(Tresult)(eval());
        }
    }

    /* Slicing and indexing */
    SliceProxy!(rank, 1) opSlice()
    {
        return typeof(return)(&this, [SliceBounds(0, _dim[0])]);
    }

    SliceProxy!(rank, 1) opSlice(size_t lo, size_t up)
    {
        return typeof(return)(&this, [SliceBounds(lo, up)]);
    }

    SliceProxy!(rank - 1, 1) opIndex(size_t i)
    {
        return typeof(return)(&this, [SliceBounds(i)]);
    }
}

/* Operations that are common for both arrays and matrices */
mixin template basicOperations(StorageType storageType,
                               StorageOrder storageOrder)
{
    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _data);
    }
}

/** Slice of a compact multidimensional array.
    Unlike arrays slices do not perform memory management.
*/
struct Slice(T, uint rank_, StorageOrder storageOrder = StorageOrder.rowMajor)
{
    enum size_t[] dimPattern = [repeatTuple!(rank_, dynamicSize)];

    mixin storage!(T, dimPattern, StorageType.dynamic, storageOrder);

    /* Make slice of an array or slice */
    private this(SourceType)(ref SourceType source, SliceBounds[] bounds)
        if(isStorage!SourceType)
            in
            {
                assert(bounds.length == source.rank);
                assert(count!("a.isRegularSlice")(bounds) == rank);
            }
    body
    {
        size_t bndLo = 0; // Lower boundary in the container
        size_t bndUp = 0; // Upper boundary in the container

        /* Dimensions and strides should be copied for all regular slices
           and omitted for indices.
           Boundaries should not cover additional elements.
        */
        uint idest = 0;
        foreach(i, b; bounds)
        {
            bndLo += source._stride[i] * b.lo;
            if(b.isRegularSlice)
            {
                bndUp += source._stride[i] * (b.up - 1);
                _dim[idest] = b.up - b.lo;
                _stride[idest] = source._stride[i];
                ++idest;
            }
            else
                bndUp += source._stride[i] * b.up;
        }
        ++bndUp;

        _data = source._data[bndLo..bndUp];
    }

    mixin basicOperations!(StorageType.dynamic, storageOrder);
}

/** Multidimensional compact array
*/
struct Array(T, params...)
{
    /* Check the transposition flag (false by default). */
    static if(isValueOfTypeStrict!(StorageOrder, params[$-1]))
    {
        enum StorageOrder storageOrder = params[$-1];
        alias params[0..$-1] dimTuple;
    }
    else
    {
        enum StorageOrder storageOrder = StorageOrder.rowMajor;
        alias params dimTuple;
    }

    /* Check and store array dimensions */
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    enum size_t[] dimPattern = [dimTuple];

    enum StorageType storageType =
        canFind(dimPattern, dynamicSize)
        ? StorageType.resizeable
        : StorageType.fixed;

    mixin storage!(T, dimPattern, storageType, storageOrder);

    static if(storageType == StorageType.fixed)
        // Convert ordinary 1D array to static MD array with dense storage
        this(T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _data = source;
        }
    else
        /* Convert ordinary 1D array to dense multidimensional array
           with given dimensions
         */
        this(T[] source, size_t[] dim)
            in
            {
                assert(dim.length == rank);
                assert(source.length == reduce!("a * b")(dim));
                foreach(i, d; dimPattern)
                    if(d != dynamicSize)
                        assert(d == dim[i]);
            }
        body
        {
            _data = source;
            _dim = dim;
            _stride = calcDenseStrides(
                _dim, storageOrder == StorageOrder.columnMajor);
        }

    /* Slicing and indexing */
    auto constructSlice(uint sliceRank)(Array* source, SliceBounds[] bounds)
    {
        return Slice!(T, sliceRank, storageOrder)(source, bounds);
    }

    mixin sliceProxy!(Array, Array.constructSlice);
    mixin basicOperations!(storageType, storageOrder);
}

unittest
{
    alias Slice!(int, 2) S;
    alias Array!(int, 2, 0) A;
}

unittest // Slicing
{
    auto a = Array!(int, 2, 3, 4)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[1, 5, 9],
               [13, 17, 21]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[1, 2],
                [5, 6],
                [9, 10]],
               [[13, 14],
                [17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[][1][]
           == [[4, 5, 6, 7],
               [16, 17, 18, 19]]);
    assert(cast(int[]) a[][1][1]
           == [5, 17]);
    assert(cast(int[][]) a[][1][1..3]
           == [[5, 6],
               [17, 18]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[5, 9],
               [17, 21]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[5, 6],
                [9, 10]],
               [[17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[1][][]
           == [[12, 13, 14, 15],
               [16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][][1]
           == [13, 17, 21]);
    assert(cast(int[][]) a[1][][1..3]
           == [[13, 14],
               [17, 18],
               [21, 22]]);
    assert(cast(int[]) a[1][1][]
           == [16, 17, 18, 19]);
    assert(a[1][1][1] == 17);
    assert(cast(int[]) a[1][1][1..3]
           == [17, 18]);
    assert(cast(int[][]) a[1][1..3][]
           == [[16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [17, 21]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[17, 18],
               [21, 22]]);
}
