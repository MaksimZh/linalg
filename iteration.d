// Written in the D programming language.

/** Do something useful with ranges iterating them element by element.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.iteration;

import std.range;

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

void copy(Tsource, Tdest)(Tsource source, Tdest dest)
    if(isInputRange!Tsource && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = source.front;
        source.popFront();
    }
}

unittest
{
    int[] a = [1, 2, 3];
    int[] b = [0, 0, 0];
    copy(a, b);
    assert(b == [1, 2, 3]);
}

void applyUnary(string op, Tsource, Tdest)(Tsource source, Tdest dest)
    if(isInputRange!Tsource && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = mixin(op ~ "source.front");
        source.popFront();
    }
}

unittest
{
    int[] a = [1, 2, 3];
    int[] b = [0, 0, 0];
    applyUnary!("-")(a, b);
    assert(b == [-1, -2, -3]);
}

void applyBinary(string op, Tsource1, Tsource2, Tdest)(Tsource1 source1,
                                                       Tsource2 source2,
                                                       Tdest dest)
    if(isInputRange!Tsource1 && isInputRange!Tsource2 && isInputRange!Tdest)
{
    foreach(ref d; dest)
    {
        d = mixin("source1.front" ~ op ~ "source2.front");
        source1.popFront();
        source2.popFront();
    }
}

unittest
{
    int[] a1 = [1, 2, 3];
    int[] a2 = [4, 5, 6];
    int[] b = [0, 0, 0];
    applyBinary!("+")(a1, a2, b);
    assert(b == [5, 7, 9]);
}
