// Written in the D programming language.

/** Arrays and matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module containers;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import aux;
import mdarray;
import stride;
import iteration;

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
                       bool allowResize,
                       StorageOrder storageOrder)
{
    static assert(is(typeof(dimPattern[0]) : size_t));

    alias T ElementType; // Type of the array elements
    public enum uint rank = dimPattern.length; // Number of dimensions

    enum StorageType storageType =
        canFind(dimPattern, dynamicSize)
        ? (allowResize ? StorageType.resizeable : StorageType.dynamic)
        : StorageType.fixed;

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

    ByElement!(ElementType) byElement()
    {
        return ByElement!(ElementType)(_dim, _stride, _data);
    }

    ref auto opAssign(SourceType)(SourceType source)
        if(isStorage!SourceType)
            in
            {
                assert(isCompatibleDimensions(source._dim));
            }
    body
    {
        static if(storageType == StorageType.resizeable)
            if(_dim != source._dim)
                setAllDimensions(source._dim);
        iteration.copy(source.byElement(), this.byElement());
        return this;
    }
}

/** Slice of a compact multidimensional array.
    Unlike arrays slices do not perform memory management.
*/
struct Slice(T, uint rank_, StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    enum size_t[] dimPattern = [repeatTuple!(rank_, dynamicSize)];
    enum StorageOrder storageOrder = storageOrder_;

    mixin storage!(T, dimPattern, false, storageOrder);

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

    mixin storage!(T, dimPattern, true, storageOrder);

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

unittest // Type properties and dimensions
{
    {
        alias Slice!(int, 3) A;
        static assert(is(A.ElementType == int));
        static assert(A.storageType == StorageType.dynamic);
        static assert(A.storageOrder == StorageOrder.rowMajor);
    }
    {
        alias Array!(int, dynamicSize, dynamicSize, dynamicSize) A;
        static assert(is(A.ElementType == int));
        static assert(A.storageType == StorageType.resizeable);
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(24)), [2, 3, 4]);
        assert(a.length == 2);
        assert(a.dimensions == [2, 3, 4]);
    }
    {
        alias Array!(int, 2, 3, 4) A;
        static assert(is(A.ElementType == int));
        static assert(A.storageType == StorageType.fixed);
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(24)));
        assert(a.length == 2);
        assert(a.dimensions == [2, 3, 4]);
    }
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

unittest // Slicing, transposed
{
    auto a = Array!(int, 2, 3, 4, StorageOrder.columnMajor)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 6, 12, 18],
                [2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[1, 7, 13, 19],
                [3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[6, 8, 10],
               [7, 9, 11]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[6, 12],
                [8, 14],
                [10, 16]],
               [[7, 13],
                [9, 15],
                [11, 17]]]);

    assert(cast(int[][]) a[][1][]
           == [[2, 8, 14, 20],
               [3, 9, 15, 21]]);
    assert(cast(int[]) a[][1][1]
           == [8, 9]);
    assert(cast(int[][]) a[][1][1..3]
           == [[8, 14],
               [9, 15]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[8, 10],
               [9, 11]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[8, 14],
                [10, 16]],
               [[9, 15],
                [11, 17]]]);
    assert(cast(int[][]) a[1][][]
           == [[1, 7, 13, 19],
               [3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][][1]
           == [7, 9, 11]);
    assert(cast(int[][]) a[1][][1..3]
           == [[7, 13],
               [9, 15],
               [11, 17]]);
    assert(cast(int[]) a[1][1][]
           == [3, 9, 15, 21]);
    assert(a[1][1][1]
           == 9);
    assert(cast(int[]) a[1][1][1..3]
           == [9, 15]);
    assert(cast(int[][]) a[1][1..3][]
           == [[3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [9, 11]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[9, 15],
               [11, 17]]);
}

unittest // Iterators
{
    // Normal
    {
        auto a = Array!(int, 2, 3, 4)(array(iota(24)));
        int[] test = array(iota(24));
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }

    // Transposed
    {
        auto a = Array!(int, 2, 3, 4,
                        StorageOrder.columnMajor)(array(iota(0, 24)));
        int[] test = [0, 6, 12, 18,
                      2, 8, 14, 20,
                      4, 10, 16, 22,

                      1, 7, 13, 19,
                      3, 9, 15, 21,
                      5, 11, 17, 23];
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Iterators for slice
{
    {
        auto a = Array!(int, 2, 3, 4)(array(iota(24)));
        int[] test = [5, 6,
                      9, 10,

                      17, 18,
                      21, 22];
        int[] result = [];
        foreach(v; a[][1..3][1..3].byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Assignment
{
    alias Array!(int, 2, 3, 4) A;
    A a, b;
    a = A(array(iota(0, 24)));
    auto test = [[[0, 1, 2, 3],
                  [4, 5, 6, 7],
                  [8, 9, 10, 11]],
                 [[12, 13, 14, 15],
                  [16, 17, 18, 19],
                  [20, 21, 22, 23]]];
    assert(cast(int[][][])(b = a) == test);
    assert(cast(int[][][])b == test);
    alias Array!(int, 0, 3, 0) A1;
    A1 a1, b1;
    a1 = A1(array(iota(0, 24)), [2, 3, 4]);
    assert(cast(int[][][])(b1 = a1) == test);
    assert(cast(int[][][])b1 == test);
}

unittest // Assignment for slices
{
    auto a = Array!(int, 2, 3, 4)(array(iota(0, 24)));
    auto b = Array!(int, 2, 2, 2)(array(iota(24, 32)));
    auto c = a[][1..3][1..3];
    auto test = [[[0, 1, 2, 3],
                  [4, 24, 25, 7],
                  [8, 26, 27, 11]],
                 [[12, 13, 14, 15],
                  [16, 28, 29, 19],
                  [20, 30, 31, 23]]];
    assert(cast(int[][][]) (c = b) == cast(int[][][]) b);
    assert(cast(int[][][]) a == test);
    a[1][1][1] = 100;
    assert(a[1][1][1] == 100);
}
