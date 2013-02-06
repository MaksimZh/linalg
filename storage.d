// Written in the D programming language.

/** Implementation of common features of arrays and matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.storage;

import std.algorithm;
import std.traits;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.aux;
import linalg.mdarray;
import linalg.stride;
import linalg.iterators;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor,   /// [0][0][0], ..., [0][0][N], [0][1][0], ...
    columnMajor /// [0][0][0], ..., [N][0][0], [0][1][0], ...
}

/* Structure to store slice boundaries compactly */
package struct SliceBounds
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
    bool isRegularSlice() pure const
    {
        return !(lo == up);
    }
}

/** Storage and dimension management for arrays and matrices
 *  Params:
 *      T = type of the array elements
 *      dimPattern = tuple of dimensions
 *      isView = view flag (views do not perform memory management)
 *      storageOrder = storage order (row- or column-major)
 */
struct Storage(T, params...)
{
    public // Check and process parameters
    {
        enum size_t[] dimPattern = [params[0..($-2)]];

        alias T ElementType; // Type of the array elements
        public enum uint rank = dimPattern.length; // Number of dimensions
        enum StorageOrder storageOrder = params[$-1];

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = !canFind(dimPattern, dynamicSize);
        /* Whether memory management is allowed */
        enum bool isResizeable = !isStatic && !params[$-2];
    }

    /* dimensions, strides and data */
    package static if(isStatic)
    {
        enum size_t[] _dim = dimPattern;
        enum size_t[] _stride =
            calcDenseStrides(_dim, storageOrder == StorageOrder.columnMajor);
        ElementType[calcDenseContainerSize(_dim)] _data;
    }
    else
    {
        static if(isResizeable)
        {
            size_t[rank] _dim = dimPattern;
            size_t[rank] _stride;
        }
        else
        {
            const size_t[rank] _dim;
            const size_t[rank] _stride;
        }
        ElementType[] _data;
    }

    /* Leading dimension */
    static if(dimPattern[0] != dynamicSize)
        public enum size_t length = dimPattern[0];
    else
        public @property size_t length() pure const { return _dim[0]; }

    /* Full dimensions array */
    static if(isStatic)
        public enum size_t[rank] dimensions = _dim;
    else
        public @property size_t[rank] dimensions() pure const { return _dim; }

    /* Test dimensions for compatibility */
    bool isCompatibleDimensions(in size_t[] dim) pure
    {
        static if(isResizeable)
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
    static if(isResizeable)
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

        /* Adjust all dimensions to make them the same as in source storage */
        void fit(Tsource)(in Tsource source) pure
            in
            {
                assert(isCompatibleDimensions(source._dim));
            }
        body
        {
            if(_dim != source._dim)
                setAllDimensions(source._dim);
        }
    }

    /* Constructor taking built-in array as parameter */
    static if(isStatic)
    {
        this()(in T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _data = source;
        }
    }
    else
    {
        this()(T[] source, in size_t[] dim)
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

        static if(!isResizeable)
        {
            this()(T[] data, size_t[rank] dim, size_t[rank] stride)
            {
                _data = data;
                _dim = dim;
                _stride = stride;
            }
        }
    }

    /* Constructor building a slice of another storage */
    static if(!isStatic && !isResizeable)
    {
        package this(SourceType)(ref SourceType source, in SliceBounds[] bounds)
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
    }

    /* Convert to built-in multidimensional array */
    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _data);
    }

    /* Iterator */
    ByElement!(ElementType) byElement()
    {
        return ByElement!(ElementType)(_dim, _stride, _data);
    }

    /* Access element by set of indices */
    ref ElementType accessByIndex(SliceBounds[] bounds)
        in
        {
            assert(count!("a.isRegularSlice")(bounds) == 0);
        }
    body
    {
        size_t index = 0; // Position in the container
        foreach(i, b; bounds)
            index += _stride[i] * b.lo;
        return _data[index];
    }
}

template isStorage(T)
{
    enum bool isStorage = isInstanceOf!(Storage, T);
}

unittest // Type properties, dimensions and data
{
    {
        alias Storage!(int, dynamicSize, dynamicSize, dynamicSize,
                       false, StorageOrder.rowMajor) S;
        static assert(is(S.ElementType == int));
        static assert(!(S.isStatic));
        static assert(S.isResizeable);
        static assert(S.storageOrder == StorageOrder.rowMajor);
        S s = S(array(iota(24)), [2, 3, 4]);
        assert(s.length == 2);
        assert(s.dimensions == [2, 3, 4]);
        assert(cast(int[][][]) s
               == [[[0, 1, 2, 3],
                    [4, 5, 6, 7],
                    [8, 9, 10, 11]],
                   [[12, 13, 14, 15],
                    [16, 17, 18, 19],
                    [20, 21, 22, 23]]]);
    }
    {
        alias Storage!(double, 2, 3, 4,
                       false, StorageOrder.columnMajor) S;
        static assert(is(S.ElementType == double));
        static assert(S.isStatic);
        static assert(S.storageOrder == StorageOrder.columnMajor);
        S s = S(array(iota(24.)));
        assert(s.length == 2);
        assert(s.dimensions == [2, 3, 4]);
        assert(cast(double[][][]) s
               == [[[0, 6, 12, 18],
                    [2, 8, 14, 20],
                    [4, 10, 16, 22]],
                   [[1, 7, 13, 19],
                    [3, 9, 15, 21],
                    [5, 11, 17, 23]]]);
    }
}

unittest // Iterators
{
    // Normal
    {
        auto a = Storage!(int, 2, 3, 4, false, StorageOrder.rowMajor)(
            array(iota(24)));
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == array(iota(24)));
    }

    // Transposed
    {
        auto a = Storage!(int, 2, 3, 4, false, StorageOrder.columnMajor)(
            array(iota(24)));
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == [0, 6, 12, 18,
                          2, 8, 14, 20,
                          4, 10, 16, 22,

                          1, 7, 13, 19,
                          3, 9, 15, 21,
                          5, 11, 17, 23]);
    }
}

version(none)
{
/* Operations that are common for both arrays and matrices */
mixin template basicOperations(FinalType,
                               StorageType storageType,
                               StorageOrder storageOrder)
{
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
        linalg.iteration.copy(source.byElement(), this.byElement());
        return this;
    }

    bool opEquals(SourceType)(SourceType source)
        if(isStorage!SourceType)
            in
            {
                assert(source._dim == _dim);
            }
    body
    {
        return equal(source.byElement(), this.byElement());
    }

    FinalType opUnary(string op)()
        if(((op == "-") || (op == "+"))
           && (is(typeof(mixin(op ~ "this.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        linalg.iteration.applyUnary!op(this.byElement(), result.byElement());
        return result;
    }

    version(none) //XXX: DMD issue 9235
    {
    FinalType opBinary(string op, Trhs)(Trhs rhs)
        if(((op == "-") || (op == "+"))
           && isStorage!Trhs
           && (is(typeof(mixin("this.byElement().front"
                               ~ op ~ "rhs.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        linalg.iteration.applyBinary!op(this.byElement(),
                                        rhs.byElement(),
                                        result.byElement());
        return result;
    }
    }
}
}
