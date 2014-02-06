// Written in the D programming language.

/**
 * Implementation of ranges for regular storage.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.ranges.regular;

import std.string;

import linalg.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

debug import linalg.debugging;
debug import std.stdio;

version(unittest)
{
    import std.conv;
    import std.range;
    import std.array;
}

/*
 * By-element iteration that goes like in folded loops:
 * foreach(i0; 0..dim0){ foreach(i1; 0..dim1){ ... }}
 */
struct ByElement(ElementType, size_t rank)
{
    //TODO: optimize for 2d
    private
    {
         size_t[] _dim;
         size_t[] _stride;
        ElementType[] _data;

        uint _rank;
        ElementType* _ptr;
        size_t[] _index;
        bool _empty;
    }

    this(ElementType[] data, in size_t[] dim, in size_t[] stride) pure
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        debug(range)
        {
            debugOP.writefln("ByElement!(%d).this()", rank);
            mixin(debugIndentScope);
            debugOP.writefln("data = <%X>, %d",
                             data.ptr, data.length);
            debugOP.writeln("dim = ", dim);
            debugOP.writeln("stride = ", stride);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }

        _dim = dim;
        _stride = stride;
        _data = data;
        _rank = cast(uint) dim.length;
        _ptr = _data.ptr;
        _index = new size_t[_rank];
        _empty = false;
    }

    @property bool empty() pure  { return _empty; }
    @property ref ElementType front() pure { return *_ptr; }

    void popFront() pure
    {
        int i = _rank - 1;
        while((i >= 0) && (_index[i] == _dim[i] - 1))
        {
            _ptr -= _stride[i] * _index[i];
            _index[i] = 0;
            --i;
        }
        if(i >= 0)
        {
            _ptr += _stride[i];
            ++_index[i];
        }
        else
            _empty = true;
    }
}

/*
 * Iteration by row or column (depending on strides)
 */
struct ByLine(ElementType, ResultType)
{
    private
    {
        ElementType[] _data;
         size_t _dimExt;
         size_t _strideExt;
         size_t _dimInt;
         size_t _strideInt;

        ElementType* _ptr;
         ElementType* _ptrFin;
    }

    this(ElementType[] data, in size_t[2] dim, in size_t[2] stride) pure
    {
        _data = data;
        _dimExt = dim[0];
        _strideExt = stride[0];
        _dimInt = dim[1];
        _strideInt = stride[1];
        _ptr = _data.ptr;
        _ptrFin = _data.ptr + dim[0] * stride[0];
    }

    @property bool empty() pure  { return _ptr >= _ptrFin; }

    @property auto front() pure
    {
        return mixin((is(ResultType == void)
                      ? ""
                      : "ResultType")
                     ~ "(StorageRegular1D!(ElementType, dynsize)(
                             _ptr[0..((_dimInt - 1) * _strideInt + 1)],
                             _dimInt, _strideInt))");
    }

    void popFront() pure { _ptr += _strideExt; }
}

version(unittest)
{
    struct Foo(T)
    {
        StorageRegular1D!(T, dynsize) storage;

        this(StorageRegular1D!(T, dynsize) storage)
        {
            this.storage = storage;
        }

        auto eval() pure
        {
            return cast(T[]) storage;
        }

        string toString()
        {
            return to!string(cast(T[]) storage);
        }
    }
}

unittest
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: ByLine");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto rng = ByLine!(int, Foo!int)(
        array(iota(24)), [6, 4], [4, 1]);
    int[][] result = [];
    foreach(r; rng)
        result ~= [r.eval()];
    assert(result == [[0, 1, 2, 3],
                      [4, 5, 6, 7],
                      [8, 9, 10, 11],
                      [12, 13, 14, 15],
                      [16, 17, 18, 19],
                      [20, 21, 22, 23]]);
}

unittest
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: ByLine");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto rng = ByLine!(int, Foo!int)(
        array(iota(24)), [4, 6], [1, 4]);
    int[][] result = [];
    foreach(r; rng)
        result ~= [r.eval()];
    assert(result == [[0, 4, 8, 12, 16, 20],
                      [1, 5, 9, 13, 17, 21],
                      [2, 6, 10, 14, 18, 22],
                      [3, 7, 11, 15, 19, 23]]);
}

/*
 * Iteration by matrix block
 */
struct ByBlock(ElementType, ResultType, StorageOrder storageOrder)
{
    private
    {
         size_t[2] _dim;
         size_t[2] _stride;
         size_t[2] _substride;
         size_t[2] _subdim;
         size_t _len;
        ElementType[] _data;

        ElementType* _ptr;
        size_t _i, _j;
        bool _empty;
    }

    this(ElementType[] data, size_t[2] dim, size_t[2] stride,
         size_t[2] subdim) pure
        in
        {
            assert(dim[0] % subdim[0] == 0);
            assert(dim[1] % subdim[1] == 0);
        }
    body
    {
        debug(range)
        {
            debugOP.writeln("ByBlock.this()");
            mixin(debugIndentScope);
            debugOP.writefln("data = <%X>, %d",
                             data.ptr, data.length);
            debugOP.writeln("dim = ", dim);
            debugOP.writeln("stride = ", stride);
            debugOP.writeln("subdim = ", subdim);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }

        _substride = stride;
        _subdim = subdim;
        _dim = [dim[0] / subdim[0], dim[1] / subdim[1]];
        _stride = [stride[0] * subdim[0], stride[1] * subdim[1]];
        _len = (_subdim[0] - 1) * _substride[0]
            + (_subdim[1] - 1) * _substride[1]
            + 1;
        _data = data;
        _ptr = _data.ptr;
        _i = 0;
        _j = 0;
        _empty = false;
    }

    @property bool empty() pure  { return _empty; }

    @property auto front() pure
    {
        return mixin((is(ResultType == void)
                      ? ""
                      : "ResultType")
                     ~ "(StorageRegular2D!(ElementType, storageOrder,
                                           dynsize, dynsize)(
                                               _ptr[0.._len],
                                               _subdim, _substride))");
    }

    void popFront() pure
    {
        if(_j == _dim[1] - 1)
        {
            _ptr -= _stride[1] * _j;
            _j = 0;
            if(_i == _dim[0] - 1)
            {
                _empty = true;
            }
            else
            {
                _ptr += _stride[0];
                ++_i;
            }
        }
        else
        {
            _ptr += _stride[1];
            ++_j;
        }
    }
}

version(unittest)
{
    struct Foo2(T)
    {
        StorageRegular2D!(T, StorageOrder.row,
                          dynsize, dynsize) storage;

        this(StorageRegular2D!(T, StorageOrder.row,
                               dynsize, dynsize) storage)
        {
            this.storage = storage;
        }

        auto eval() pure
        {
            return cast(T[][]) storage;
        }

        string toString()
        {
            return to!string(cast(T[][]) storage);
        }
    }
}

unittest
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: ByBlock");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto rng = ByBlock!(int, Foo2!int, StorageOrder.row)(
        array(iota(24)), [4, 6], [6, 1], [2, 3]);
    int[][][] result = [];
    foreach(r; rng)
        result ~= [r.eval()];
    assert(result == [[[0, 1, 2],
                       [6, 7, 8]],
                      [[3, 4, 5],
                       [9, 10, 11]],
                      [[12, 13, 14],
                       [18, 19, 20]],
                      [[15, 16, 17],
                       [21, 22, 23]]]);
}
