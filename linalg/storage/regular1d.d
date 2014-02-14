// Written in the D programming language.

/**
 * Regular one-dimensional storage.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013-2014 Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.storage.regular1d;

import std.algorithm;
import std.traits;

debug import linalg.aux.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.aux.types;
import linalg.storage.slice;

private // Auxiliary functions
{
    // Convert storage to built-in multidimensional array
    auto toArray(T)(T[] container,
                    size_t dim,
                    size_t stride) pure
    {
        auto result = new T[](dim);
        foreach(i; 0..dim)
            result[i] = container[i*stride];
        return result;
    }
}

/* Regular one-dimensional storage */
struct StorageRegular1D(T, size_t dim_)
{
    public // Check and process parameters
    {
        enum size_t dimPattern = dim_;

        alias T ElementType; // Type of the array elements
        public enum uint rank = 1; // Number of dimensions

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = dimPattern != dynsize;

        static if(isStatic)
            alias ElementType[dimPattern] ContainerType;
        else
            alias ElementType[] ContainerType;
    }

    private // Container, dimensions, strides
    {
        ContainerType _container;

        static if(isStatic)
        {
            enum size_t _dim = dimPattern;
            enum size_t _stride = 1;
        }
        else
        {
            size_t _dim;
            size_t _stride;
        }
    }

    /* Constructors */
    static if(isStatic)
    {
        this(ElementType[] array) pure
            in
            {
                assert(array.length == _container.length);
            }
        body
        {
            _container = array;
            debug(linalg_memory) dfMemCopied(array, _container);
        }
    }
    else
    {
        this(size_t dim)
        {
            _dim = dim;
            _stride = 1;
            _reallocate();
        }

        this(ElementType[] array) pure
        {
            this(array, array.length, 1);
        }

        this(ElementType[] array,
             size_t dim, size_t stride) pure
        {
            debug(linalg_memory) dfMemAbandon(_container);
            _container = array;
            _dim = dim;
            _stride = stride;
            debug(linalg_memory) dfMemReferred(_container);
        }

        this(Tsource)(auto ref Tsource source) pure
            if(isStorageRegular1D!Tsource)
        {
            this(source.container, source.dim, source.stride);
        }
    }

    public // Dimensions and memory
    {
        @property auto container() pure { return _container[]; }
        @property size_t dim() pure const { return _dim; }
        alias dim length;
        @property size_t stride() pure const { return _stride; }

        /* Test dimensions for compatibility */
        static bool isCompatDim(size_t dim) pure
        {
            static if(isStatic)
            {
                return dim == dimPattern;
            }
            else
            {
                return (dim == dimPattern) || (dimPattern == dynsize);
            }
        }

        static if(!isStatic)
        {
            /* Recalculate strides and reallocate container
               for current dimensions
             */
            private void _reallocate() pure
            {
                debug(linalg_memory) dfMemAbandon(_container);
                _stride = 1;
                _container = new ElementType[_dim];
                debug(linalg_memory) dfMemAllocated(_container);
            }

            void setDim(size_t dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                _dim = dim;
                _reallocate();
            }
        }
    }

    public // Slices and indices support
    {
        //NOTE: depends on DMD pull-request 443
        private size_t _mapIndex(size_t i) pure const
        {
            return i * _stride;
        }

        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure const
        {
            static assert(dimIndex == 0);
            return _dim;
        }

        auto opIndex() pure
        {
            return StorageRegular1D!(ElementType, dynsize)(
                cast()_container[], length, _stride);
        }

        ref auto opIndex(size_t i) pure
        {
            return _container[_mapIndex(i)];
        }

        auto opIndex(Slice s) pure
        {
            return StorageRegular1D!(ElementType, dynsize)(
                cast()_container[_mapIndex(s.lo).._mapIndex(s.upReal)],
                s.length, _stride * s.stride);
        }
    }
    
    /* Convert to built-in array */
    ElementType[] opCast() pure
    {
        return toArray(_container, _dim, _stride);
    }

    public // Ranges
    {
        @property auto byElement() pure
        {
            return ByElement!ElementType(
                _container.ptr, _dim, _stride);
        }
    }
}

/* Detect whether T is one-dimensional regular storage */
template isStorageRegular1D(T)
{
    enum bool isStorageRegular1D = isInstanceOf!(StorageRegular1D, T);
}

struct ByElement(ElementType)
{
    private
    {
        ElementType* _ptr;
        const size_t _dim;
        const size_t _stride;
        const ElementType* _ptrFin;
    }

    this(ElementType* ptr, size_t dim, size_t stride) pure
    {
        _ptr = ptr;
        _dim = dim;
        _stride = stride;
        _ptrFin = ptr + dim * stride;
    }

    @property bool empty() pure  { return _ptr >= _ptrFin; }
    @property ref ElementType front() pure { return *_ptr; }
    void popFront() pure { _ptr += _stride; }
}

unittest // Type properties
{
    alias StorageRegular1D!(int, 3) Si3;
    alias StorageRegular1D!(int, dynsize) Sid;

    // dimPattern
    static assert(Si3.dimPattern == 3);
    static assert(Sid.dimPattern == dynsize);

    // ElementType
    static assert(is(Si3.ElementType == int));
    static assert(is(Sid.ElementType == int));

    // rank
    static assert(Si3.rank == 1);
    static assert(Sid.rank == 1);

    // isStatic
    static assert(Si3.isStatic);
    static assert(!(Sid.isStatic));
}

unittest // Constructors, cast
{
    debug mixin(debugUnittestBlock("Constructors, cast"));

    int[] a = [1, 2, 3, 4, 5, 6];

    assert(cast(int[]) StorageRegular1D!(int, dynsize)(3)
           == [int.init, int.init, int.init]);
    assert(cast(int[]) StorageRegular1D!(int, 6)(a) == a);
    assert(cast(int[]) StorageRegular1D!(int, dynsize)(a) == a);
    assert(cast(int[]) StorageRegular1D!(int, dynsize)(a, 3, 2)
           == [1, 3, 5]);
}

unittest // Dimensions and memory
{
    debug mixin(debugUnittestBlock("Dimensions and memory"));

    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = StorageRegular1D!(int, dynsize)(src, 3, 2);
    assert(a.container.ptr == src.ptr);
    assert(a.container == [1, 2, 3, 4, 5, 6]);
    assert(a.dim == 3);
    assert(a.stride == 2);

    assert(StorageRegular1D!(int, 3).isCompatDim(3) == true);
    assert(StorageRegular1D!(int, 3).isCompatDim(4) == false);
    assert(StorageRegular1D!(int, dynsize).isCompatDim(3) == true);
    assert(StorageRegular1D!(int, dynsize).isCompatDim(4) == true);
    assert(a.isCompatDim(3) == true);
    assert(a.isCompatDim(4) == true);

    //TODO: test setDim
}

unittest // Indices and slices
{
    debug mixin(debugUnittestBlock("Indices and slices"));
    debug debugOP.writeln("Waiting for pull request 443");
}

unittest // Ranges
{
    debug mixin(debugUnittestBlock("Ranges"));

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = StorageRegular1D!(int, 6)(src);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 2, 3, 4, 5, 6]);
        }
    }
    {
        auto a = StorageRegular1D!(int, dynsize)(src, 3, 2);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 3, 5]);
        }
    }
}
