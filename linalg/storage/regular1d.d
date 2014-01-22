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

debug import linalg.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.types;
import linalg.operations.basic;
import linalg.storage.slice;
import linalg.ranges.regular;

private // Auxiliary functions
{
    // Convert storage to built-in multidimensional array
    auto toArray(T)(in T[] container,
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
            debug(memory) dfMemCopied(array, _container);
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
            debug(memory) dfMemAbandon(_container);
            _container = array;
            _dim = dim;
            _stride = stride;
            debug(memory) dfMemReferred(_container);
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
                debug(memory) dfMemAbandon(_container);
                _stride = 1;
                _container = new ElementType[_dim];
                debug(memory) dfMemAllocated(_container);
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
            debug(slice) debugOP.writeln("slice");
            return StorageRegular1D!(ElementType, dynsize)(
                cast()_container[], length, _stride);
        }

        ref auto opIndex(size_t i) pure
        {
            return _container[_mapIndex(i)];
        }

        auto opIndex(Slice s) pure
        {
            debug(slice) debugOP.writeln("slice ", s);
            return StorageRegular1D!(ElementType, dynsize)(
                cast()_container[_mapIndex(s.lo).._mapIndex(s.upReal)],
                s.length, _stride * s.stride);
        }
    }

    /* Makes copy of the data and returns new storage referring to it.
       The storage returned is always dynamic.
    */
    @property ref auto dup() pure
    {
        debug(storage)
        {
            debugOP.writefln("StorageRegular1D<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        auto result = StorageRegular1D!(Unqual!ElementType, dynsize)(_dim);
        copy(this, result);
        return result;
    }

    /* Convert to built-in array */
    ElementType[] opCast() pure const
    {
        return toArray(_container, _dim, _stride);
    }

    public // Ranges
    {
        @property auto byElement() pure
        {
            return ByElement!(ElementType, 1)(
                _container, _dim, _stride);
        }
    }
}

/* Detect whether T is one-dimensional regular storage */
template isStorageRegular1D(T)
{
    enum bool isStorageRegular1D = isInstanceOf!(StorageRegular1D, T);
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
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Constructors, cast");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Dimensions and memory");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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

    auto b = a.dup;
    assert(b.container.ptr != a.container.ptr);
    assert(b.container == [1, 3, 5]);
    assert(b.dim == 3);
    assert(b.stride == 1);

    a.setDim(5);
    assert(a.dim == 5);
}

unittest // Indices and slices
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Indices and slices");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    debug debugOP.writeln("Waiting for pull request 443");
}

unittest // Ranges
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Ranges");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
