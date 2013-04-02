// Written in the D programming language.

module linalg.ranges.regular;

import linalg.storage.regular1d;

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

    static if(mutable)
    {
        this(ElementType[] data, size_t dim, size_t stride) pure
        {
            _data = data;
            _dim = dim;
            _stride = stride;
            _ptr = _data.ptr;
            _ptrFin = _data.ptr + dim;
        }
    }
    else
    {
        this(in ElementType[] data, size_t dim, size_t stride) pure
        {
            _data = data;
            _dim = dim;
            _stride = stride;
            _ptr = _data.ptr;
            _ptrFin = _data.ptr + dim;
        }
    }

    @property bool empty() pure const { return _ptr >= _ptrFin; }
    static if(mutable)
        @property ref ElementType front() pure { return *_ptr; }
    else
        @property ElementType front() pure { return *_ptr; }
    void popFront() pure { _ptr += _stride; }
}

struct ByElement(ElementType, size_t rank, bool mutable = true)
    if(rank > 1)
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

    static if(mutable)
    {
        this(ElementType[] data, in size_t[] dim, in size_t[] stride) pure
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
        this(in ElementType[] data, in size_t[] dim, in size_t[] stride) pure
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

    @property bool empty() pure const { return _empty; }
    static if(mutable)
        @property ref ElementType front() pure { return *_ptr; }
    else
        @property ElementType front() pure { return *_ptr; }
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
        ElementType[] _data;
        const size_t _dimExt;
        const size_t _strideExt;
        const size_t _dimInt;
        const size_t _strideInt;

        ElementType* _ptr;
        const ElementType* _ptrFin;
    }

    this(ElementType[] data,
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

    @property bool empty() pure const { return _ptr >= _ptrFin; }
    @property ResultType front() pure
    {
        return ResultType(StorageRegular1D!(ElementType, dynamicSize)(
                              _ptr[0..((_dimInt - 1) * _strideInt + 1)],
                              _dimInt, _strideInt));
    }
    void popFront() pure { _ptr += _strideExt; }
}
