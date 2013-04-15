// Written in the D programming language.

/**
 * Regular one-dimensional storage.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
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
import linalg.storage.operations;
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
        enum bool isStatic = dimPattern != dynamicSize;

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
        inout this()(inout ElementType[] array) pure
            in
            {
                assert(array.length == _container.length);
            }
        body
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular1D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d", array.ptr, array.length);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "_container = <%X>, %d",
                    _container.ptr,
                    _container.length);
                mixin(debugIndentScope);
            }
            _container = array;
        }
    }
    else
    {
        this()(size_t dim)
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular1D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writeln("dim = ", dim);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "_container = <%X>, %d",
                    _container.ptr,
                    _container.length);
                mixin(debugIndentScope);
            }
            _dim = dim;
            _stride = 1;
            _reallocate();
        }

        inout this()(inout ElementType[] array) pure
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular1D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d", array.ptr, array.length);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "_container<%X> = <%X>, %d",
                    &(_container),
                    _container.ptr,
                    _container.length);
                mixin(debugIndentScope);
            }
            this(array, array.length, 1);
        }

        inout this()(inout ElementType[] array,
                     size_t dim, size_t stride) pure
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular1D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d",
                                 array.ptr, array.length);
                debugOP.writeln("dim = ", dim);
                debugOP.writeln("stride = ", stride);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "_container<%X> = <%X>, %d",
                    &(_container),
                    _container.ptr,
                    _container.length);
                mixin(debugIndentScope);
            }
            _container = array;
            _dim = dim;
            _stride = stride;
        }
    }

    public // Dimensions and memory
    {
        @property auto container() pure inout { return _container[]; }
        @property size_t dim() pure const { return _dim; }
        alias dim length;
        @property size_t stride() pure const { return _stride; }

        /* Test dimensions for compatibility */
        bool isCompatDim(in size_t dim) pure const
        {
            static if(isStatic)
            {
                return _dim == dimPattern;
            }
            else
            {
                return (_dim == dimPattern) || (dimPattern == dynamicSize);
            }
        }

        static if(!isStatic)
        {
            /* Recalculate strides and reallocate container
               for current dimensions
             */
            private void _reallocate() pure
            {
                debug(storage)
                {
                    debugOP.writefln("StorageRegular1D<%X>._reallocate()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "_container<%X> = <%X>, %d",
                        &(_container),
                        _container.ptr,
                        _container.length);
                    mixin(debugIndentScope);
                }
                _stride = 1;
                _container = new ElementType[_dim];
            }

            void setDim(in size_t dim) pure
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

        ref inout auto opIndex() pure inout
        {
            debug(slice) debugOP.writeln("slice");
            return StorageRegular1D!(ElementType, dynamicSize)(
                _container[], length, _stride);
        }

        ref inout auto opIndex(size_t i) pure inout
        {
            return _container[_mapIndex(i)];
        }

        ref inout auto opIndex(Slice s) pure inout
        {
            debug(slice) debugOP.writeln("slice ", s);
            return StorageRegular1D!(ElementType, dynamicSize)(
                _container[_mapIndex(s.lo).._mapIndex(s.upReal)],
                s.length, _stride);
        }
    }

    /* Makes copy of the data and returns new storage referring to it.
       The storage returned is always dynamic.
    */
    @property ref auto dup() pure const
    {
        debug(storage)
        {
            debugOP.writefln("StorageRegular1D<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        StorageRegular1D!(ElementType, dimPattern) result;
        static if(!(result.isStatic))
            result.setDim(_dim);
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
            return ByElement!(ElementType, 1, true)(
                _container, _dim, _stride);
        }

        @property auto byElement() pure const
        {
            return ByElement!(ElementType, 1, false)(
                _container, _dim, _stride);
        }
    }
}

/* Detect whether $(D T) is one-dimensional regular storage */
template isStorageRegular1D(T)
{
    enum bool isStorageRegular1D = isInstanceOf!(StorageRegular1D, T);
}

unittest // Static
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Static");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto b = StorageRegular1D!(int, 4)([0, 1, 2, 3]);
    assert(b.length == 4);
    assert(cast(int[]) b == [0, 1, 2, 3]);
    assert(b.container == [0, 1, 2, 3]);

    immutable auto ib = StorageRegular1D!(int, 4)([0, 1, 2, 3]);
    assert(ib.length == 4);
    assert(cast(int[]) ib == [0, 1, 2, 3]);
    assert(ib.container == [0, 1, 2, 3]);

    // .dup
    auto d = b.dup;
    assert(cast(int[]) d == [0, 1, 2, 3]);
    assert(d.container !is b.container);

    auto d1 = ib.dup;
    assert(cast(int[]) d1 == [0, 1, 2, 3]);
    assert(d1.container !is ib.container);

    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == [0, 1, 2, 3]);
    tmp = [];
    foreach(t; ib.byElement)
        tmp ~= t;
    assert(tmp == [0, 1, 2, 3]);
    foreach(ref t; d.byElement)
        t = 4;
    assert(cast(int[]) d == [4, 4, 4, 4]);
    foreach(ref t; ib.byElement)
        t = 4;
    assert(cast(int[]) ib == [0, 1, 2, 3]);

    // Indices
    assert(b[0] == 0);
    assert(b[2] == 2);
    assert(b[3] == 3);
}

unittest // Dynamic
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular1d unittest: Dynamic");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    // Constructors
    auto a = StorageRegular1D!(int, dynamicSize)(4);
    assert(a.length == 4);
    assert(cast(int[]) a == [int.init, int.init, int.init, int.init]);
    assert(a.container == [int.init, int.init, int.init, int.init]);

    auto b = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3]);
    assert(b.length == 4);
    assert(cast(int[]) b == [0, 1, 2, 3]);
    assert(b.container == [0, 1, 2, 3]);

    auto c = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3], 2, 3);
    assert(c.length == 2);
    assert(cast(int[]) c == [0, 3]);
    assert(c.container == [0, 1, 2, 3]);

    immutable auto ia = StorageRegular1D!(int, dynamicSize)(4);
    assert(ia.length == 4);
    assert(cast(int[]) ia == [int.init, int.init, int.init, int.init]);
    assert(ia.container == [int.init, int.init, int.init, int.init]);

    immutable auto ib = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3]);
    assert(ib.length == 4);
    assert(cast(int[]) ib == [0, 1, 2, 3]);
    assert(ib.container == [0, 1, 2, 3]);

    immutable auto ic = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3], 2, 3);
    assert(ic.length == 2);
    assert(cast(int[]) ic == [0, 3]);
    assert(ic.container == [0, 1, 2, 3]);

    // .dup
    auto d = b.dup;
    assert(cast(int[]) d == [0, 1, 2, 3]);
    assert(d.container !is b.container);
    auto d1 = ic.dup;
    assert(cast(int[]) d1 == [0, 3]);
    assert(d1.container !is ic.container);

    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == [0, 1, 2, 3]);
    tmp = [];
    foreach(t; ib.byElement)
        tmp ~= t;
    assert(tmp == [0, 1, 2, 3]);
    foreach(ref t; d.byElement)
        t = 4;
    assert(cast(int[]) d == [4, 4, 4, 4]);
    foreach(ref t; ib.byElement)
        t = 4;
    assert(cast(int[]) ib == [0, 1, 2, 3]);

    // Indices
    assert(b[0] == 0);
    assert(b[2] == 2);
    assert(b[3] == 3);

    assert(c[0] == 0);
    assert(c[1] == 3);
}
