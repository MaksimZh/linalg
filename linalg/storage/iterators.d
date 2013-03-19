// Written in the D programming language.

module linalg.storage.iterators;

struct ByElement(ElementType, bool mutable = true)
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
