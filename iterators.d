// Written in the D programming language.

/** Implementation of iterators.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.iterators;

debug import std.stdio;

/* Generic iterator */
struct ByElement(T)
{
    //TODO: optimize
    private
    {
        const size_t[] _dim;
        const size_t[] _stride;
        T[] _data;

        uint _rank;
        T* _ptr;
        size_t[] _index;
        bool _empty;
    }

    this(in size_t[] dim, in size_t[] stride, T[] data)
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

    @property bool empty() { return _empty; }
    @property ref T front() { return *_ptr; }
    void popFront()
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
