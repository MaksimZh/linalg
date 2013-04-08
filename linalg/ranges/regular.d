// Written in the D programming language.

module linalg.ranges.regular;

import std.string;

import linalg.types;
import linalg.storage.regular1d;

debug import linalg.debugging;
debug import std.stdio;

version(unittest)
{
    import std.conv;
    import std.range;
    import std.array;
}

struct ByElement(ElementType, size_t rank, bool mutable = true)
    if(rank == 1)
{
    private
    {
        static if(mutable)
            ElementType[] _data;
        else
            const ElementType[] _data;
        const size_t _dim;
        const size_t _stride;

        static if(mutable)
            ElementType* _ptr;
        else
            const(ElementType)* _ptr;
        const ElementType* _ptrFin;
    }

    mixin("this(" ~ (mutable ? "" : "in ")
          ~ "ElementType[] data, size_t dim, size_t stride) pure
        {
            debug(range)
            {
                debugOP.writeln(\"ByElement!(1).this()\");
                mixin(debugIndentScope);
                debugOP.writefln(\"data = <%%X>, %%d\",
                                 data.ptr, data.length);
                debugOP.writeln(\"dim = \", dim);
                debugOP.writeln(\"stride = \", stride);
                debugOP.writeln(\"...\");
                mixin(debugIndentScope);
            }

            _data = data;
            _dim = dim;
            _stride = stride;
            _ptr = _data.ptr;
            _ptrFin = _data.ptr + dim * stride;
        }
    ");

    @property bool empty() pure const { return _ptr >= _ptrFin; }
    mixin("@property " ~ (mutable ? "ref " : "")
          ~ "ElementType front() pure { return *_ptr; }");
    void popFront() pure { _ptr += _stride; }
}

struct ByElement(ElementType, size_t rank, bool mutable = true)
    if(rank == 2)
{
    private
    {
        const size_t[2] _dim;
        const size_t[2] _stride;
        static if(mutable)
            ElementType[] _data;
        else
            const ElementType[] _data;

        static if(mutable)
            ElementType* _ptr;
        else
            const(ElementType)* _ptr;
        size_t _i, _j;
        bool _empty;
    }

    mixin("this(" ~ (mutable ? "" : "in ")
          ~ "ElementType[] data, size_t[2] dim, size_t[2] stride) pure
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            debug(range)
            {
                debugOP.writeln(\"ByElement!(2).this()\");
                mixin(debugIndentScope);
                debugOP.writefln(\"data = <%%X>, %%d\",
                                 data.ptr, data.length);
                debugOP.writeln(\"dim = \", dim);
                debugOP.writeln(\"stride = \", stride);
                debugOP.writeln(\"...\");
                mixin(debugIndentScope);
            }

            _dim = dim;
            _stride = stride;
            _data = data;
            _ptr = _data.ptr;
            _i = 0;
            _j = 0;
            _empty = false;
        }
    ");

    @property bool empty() pure const { return _empty; }
    mixin("@property " ~ (mutable ? "ref " : "")
          ~ "ElementType front() pure { return *_ptr; }");
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

struct ByElement(ElementType, size_t rank, bool mutable = true)
    if(rank > 2)
{
    //TODO: optimize for 2d
    private
    {
        const size_t[] _dim;
        const size_t[] _stride;
        static if(mutable)
            ElementType[] _data;
        else
            const ElementType[] _data;

        uint _rank;
        static if(mutable)
            ElementType* _ptr;
        else
            const(ElementType)* _ptr;
        size_t[] _index;
        bool _empty;
    }

    mixin("this(" ~ (mutable ? "" : "in ")
          ~ "ElementType[] data, in size_t[] dim, in size_t[] stride) pure
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            debug(range)
            {
                debugOP.writefln(\"ByElement!(%%d).this()\", rank);
                mixin(debugIndentScope);
                debugOP.writefln(\"data = <%%X>, %%d\",
                                 data.ptr, data.length);
                debugOP.writeln(\"dim = \", dim);
                debugOP.writeln(\"stride = \", stride);
                debugOP.writeln(\"...\");
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
    ");

    @property bool empty() pure const { return _empty; }
    mixin("@property " ~ (mutable ? "ref " : "")
          ~ "ElementType front() pure { return *_ptr; }");

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

struct ByLine(ElementType, ResultType, bool mutable = true)
{
    private
    {
        static if(mutable)
            ElementType[] _data;
        else
            const ElementType[] _data;
        const size_t _dimExt;
        const size_t _strideExt;
        const size_t _dimInt;
        const size_t _strideInt;

        static if(mutable)
            ElementType* _ptr;
        else
            const(ElementType)* _ptr;
        const ElementType* _ptrFin;
    }

    mixin("this(" ~ (mutable ? "" : "in ")
          ~ "ElementType[] data,
             size_t dimExt, size_t strideExt,
             size_t dimInt, size_t strideInt) pure
        {
            _data = data;
            _dimExt = dimExt;
            _strideExt = strideExt;
            _dimInt = dimInt;
            _strideInt = strideInt;
            _ptr = _data.ptr;
            _ptrFin = _data.ptr + dimExt * strideExt;
        }
    ");

    @property bool empty() pure const { return _ptr >= _ptrFin; }
    mixin(format("@property %s%s%s front() pure
                  {
                      return %s(StorageRegular1D!(ElementType, dynamicSize)(
                                    _ptr[0..((_dimInt - 1) * _strideInt + 1)],
                                    _dimInt, _strideInt));
                  }",
                 mutable ? "" : "const(",
                 is(ResultType == void)
                 ? "StorageRegular1D!(ElementType, dynamicSize)"
                 : "ResultType",
                 mutable ? "" : ")",
                 is(ResultType == void)
                 ? ""
                 : "ResultType"));
    void popFront() pure { _ptr += _strideExt; }
}

version(unittest)
{
    struct Foo(T)
    {
        const StorageRegular1D!(T, dynamicSize) storage;

        this(const StorageRegular1D!(T, dynamicSize) storage) const
        {
            this.storage = storage;
        }

        auto eval() pure const
        {
            return cast(T[]) storage;
        }

        string toString() const
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

    auto rng = ByLine!(int, Foo!int, false)(array(iota(24)), 6, 4, 4, 1);
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

    auto rng = ByLine!(int, Foo!int, false)(array(iota(24)), 4, 1, 6, 4);
    int[][] result = [];
    foreach(r; rng)
        result ~= [r.eval()];
    assert(result == [[0, 4, 8, 12, 16, 20],
                      [1, 5, 9, 13, 17, 21],
                      [2, 6, 10, 14, 18, 22],
                      [3, 7, 11, 15, 19, 23]]);
}
