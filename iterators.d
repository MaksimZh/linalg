// Written in the D programming language.

/** Implementation of iterators.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
/*TODO: optimize iterators */
module linalg.iterators;

debug import std.stdio;

/* Generic iterator */
struct ByElement(ElementType, bool mutable = true)
{
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

    static if(mutable)
    {
        this(in size_t[] dim, in size_t[] stride, ElementType[] data)
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            _dim = dim;
            _stride = stride;
            _data = data;
            _rank = cast(uint) dim.length;
            _ptr = _data.ptr;
            _index = new size_t[_rank];
            _empty = false;
        }
    }
    else
    {
        this(in size_t[] dim, in size_t[] stride, in ElementType[] data)
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            _dim = dim;
            _stride = stride;
            _data = data;
            _rank = cast(uint) dim.length;
            _ptr = _data.ptr;
            _index = new size_t[_rank];
            _empty = false;
        }
    }

    @property bool empty() { return _empty; }
    static if(mutable)
        @property ref ElementType front() { return *_ptr; }
    else
        @property ElementType front() { return *_ptr; }
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

/* Generic iterator */
struct ByElementTr(ElementType, bool mutable = true)
{
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

    static if(mutable)
    {
        this(in size_t[] dim, in size_t[] stride, ElementType[] data)
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            _dim = dim;
            _stride = stride;
            _data = data;
            _rank = cast(uint) dim.length;
            _ptr = _data.ptr;
            _index = new size_t[_rank];
            _empty = false;
        }
    }
    else
    {
        this(in size_t[] dim, in size_t[] stride, in ElementType[] data)
            in
            {
                assert(stride.length == dim.length);
            }
        body
        {
            _dim = dim;
            _stride = stride;
            _data = data;
            _rank = cast(uint) dim.length;
            _ptr = _data.ptr;
            _index = new size_t[_rank];
            _empty = false;
        }
    }

    @property bool empty() { return _empty; }
    static if(mutable)
        @property ref ElementType front() { return *_ptr; }
    else
        @property ElementType front() { return *_ptr; }
    void popFront()
    {
        int i = 0;
        while((i < _rank) && (_index[i] == _dim[i] - 1))
        {
            _ptr -= _stride[i] * _index[i];
            _index[i] = 0;
            ++i;
        }
        if(i < _rank)
        {
            _ptr += _stride[i];
            ++_index[i];
        }
        else
            _empty = true;
    }
}

/* By-row iterator for 2D arrays */
struct ByMatrixRow(ElementType, SliceType)
{
    private
    {
        const size_t[2] _dim;
        const size_t[2] _stride;
        ElementType[] _data;

        ElementType* _ptr;
        const size_t _len;
        const ElementType* _ptrFinal;
    }

    this(in size_t[] dim, in size_t[] stride, ElementType[] data)
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        _dim = dim;
        _stride = stride;
        _data = data;
        _ptr = _data.ptr;
        _len = (_dim[1] - 1) * _stride[1] + 1;
        _ptrFinal = _data.ptr + (_dim[0] - 1) * _stride[0];
    }

    @property bool empty() { return !(_ptr <= _ptrFinal); }
    @property auto front()
    {
        return SliceType(_ptr[0.._len], _dim[1], _stride[1]);
    }
    void popFront()
    {
        _ptr += _stride[0];
    }
}

/* By-column iterator for 2D arrays */
struct ByMatrixCol(ElementType, SliceType)
{
    private
    {
        const size_t[2] _dim;
        const size_t[2] _stride;
        ElementType[] _data;

        ElementType* _ptr;
        const size_t _len;
        const ElementType* _ptrFinal;
    }

    this(in size_t[] dim, in size_t[] stride, ElementType[] data)
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        _dim = dim;
        _stride = stride;
        _data = data;
        _ptr = _data.ptr;
        _len = (_dim[0] - 1) * _stride[0] + 1;
        _ptrFinal = _data.ptr + (_dim[1] - 1) * _stride[1];
    }

    @property bool empty() { return !(_ptr <= _ptrFinal); }
    @property auto front()
    {
        return SliceType(_ptr[0.._len], _dim[0], _stride[0]);
    }
    void popFront()
    {
        _ptr += _stride[1];
    }
}

/* By-row iterator for 2D arrays */
struct ByMatrixBlock(ElementType, SliceType)
{
    private
    {
        const size_t[2] _subdim;
        const size_t[2] _dim;
        const size_t[2] _stride;
        ElementType[] _data;

        ElementType* _ptr;
        const size_t _len;
        size_t _irow;
        size_t _icol;
        bool _empty;
    }

    this(in size_t[] subdim, in size_t[] dim, in size_t[] stride,
         ElementType[] data)
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        _subdim = subdim;
        _dim = dim;
        _stride = stride;
        _data = data;
        _ptr = _data.ptr;
        _len = (_subdim[0] - 1) * _stride[0]
            + (_subdim[1] - 1) * _stride[1]
            + 1;
        _irow = 0;
        _icol = 0;
        _empty = false;
    }

    @property bool empty() { return _empty; }
    @property auto front()
    {
        return SliceType(_ptr[0.._len], _subdim, _stride);
    }
    void popFront()
    {
        if(_icol == _dim[1] - _subdim[1])
        {
            _ptr -= _stride[1] * _icol;
            _icol = 0;
            if(_irow == _dim[0] - _subdim[0])
                _empty = true;
            else
            {
                _ptr += _stride[0] * _subdim[0];
                _irow += _subdim[0];
            }
        }
        else
        {
            _ptr += _stride[1] * _subdim[1];
            _icol += _subdim[1];
        }
    }
}
