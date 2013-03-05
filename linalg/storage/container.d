// Written in the D programming language.

module linalg.storage.container;

debug import std.stdio;

struct DynamicArray(T)
{
    private uint* _pCounter;
    private T[] _array;

    pure invariant() { assert((_pCounter is null) || (*_pCounter > 0)); }

    public // Constructors
    {
        this(size_t length) pure
        {
            _pCounter = new uint;
            *_pCounter = 1;
            _array.length = length;
            debug(container)
                writeln("DynamicArray<", &this, ">.this()",
                        " counter<", _pCounter, "> = ", *_pCounter,
                        " ptr = ", _array.ptr);
        }

        inout this(inout T[] array) pure
        {
            auto pCounter = new uint; //HACK
            *pCounter = 1;
            this(pCounter, array);
        }

        private inout this(inout uint* pCounter, inout T[] array) pure
        {
            _pCounter = pCounter;
            _array = array;
            debug(container)
                writeln("DynamicArray<", &this, ">.this()",
                        " counter<", _pCounter, "> = ", *_pCounter,
                        " ptr = ", _array.ptr);
        }
    }

    @property bool isInitialized() pure const { return _pCounter !is null; }

    public // Reference counting interface
    {
        @property uint refNumber() pure const { return *_pCounter; }
        @property bool isShared() pure const { return *_pCounter > 1; }

        void addRef() pure const
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            ++*cast(uint*)_pCounter; //HACK
            debug(container)
                writeln("DynamicArray<", &this, ">.addRef()",
                        " counter<", _pCounter, "> = ", *_pCounter);
        }

        void remRef() pure const
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            --*cast(uint*)_pCounter; //HACK
            debug(container)
                writeln("DynamicArray<", &this, ">.remRef()",
                        " counter<", _pCounter, "> = ", *_pCounter);
        }
    }

    public // Array interface
    {
        ref inout(T) opIndex(size_t i) pure inout
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            return _array[i];
        }

        inout(DynamicArray) opSlice() pure inout
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            debug(container) writeln("DynamicArray<", &this, ">.opSlice()");
            return DynamicArray(_pCounter, _array[]);
        }

        inout(DynamicArray) opSlice(size_t lo, size_t up) pure inout
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            debug(container) writeln("DynamicArray<", &this, ">.opSlice()");
            return DynamicArray(_pCounter, _array[lo..up]);
        }

        @property inout(T*) ptr() pure inout
        {
            return _array.ptr;
        }

        @property size_t length() pure const
        {
            return _array.length;
        }

        size_t opDollar() pure const
        {
            return _array.length;
        }
    }

    @property inout(T[]) array() pure inout
        in
        {
            assert(isInitialized, "Container is not initialized");
        }
    body
    {
        return _array;
    }

    debug bool contains(in T* p) pure const
    {
        return (p >= ptr) && (p - ptr < length);
    }

    debug bool intersect(in DynamicArray a) pure const
    {
        return contains(a.ptr) || contains(a.ptr + a.length) || a.contains(ptr);
    }

    ref auto opAssign(size_t size)(const StaticArray!(T, size) source)
        in
        {
            assert(!isInitialized);
        }
    body
    {
        _pCounter = new uint;
        *_pCounter = 1;
        _array = source.array.dup;
        return this;
    }
}

unittest
{
    debug(container) writeln("refcount-unittest-begin");
    DynamicArray!int a;
    a = DynamicArray!int([0, 1, 2, 3, 4]);
    assert(a.array.ptr is a.ptr);
    assert(*a._pCounter == 1);
    assert(!a.isShared);
    a.addRef();
    assert(a.isShared);
    a.addRef();
    assert(*a._pCounter == 3);
    a.remRef();
    assert(*a._pCounter == 2);

    assert(a[2] == 2);
    auto b = a[1..4];
    assert(b._pCounter is a._pCounter);
    debug(container) writeln("refcount-unittest-end");
}

struct StaticArray(T, size_t size)
{
    private T[size] _array;

    enum bool isShared = false;

    public // Constructors
    {
        inout this(inout T[] array) pure
        {
            _array = array;
        }
    }

    public // Array interface
    {
        ref inout(T) opIndex(size_t i) pure inout
        {
            return _array[i];
        }

        inout(DynamicArray!T) opSlice() pure inout
        {
            debug(container) writeln("StaticArray<", &this, ">.opSlice()");
            return DynamicArray!T(cast(inout T[]) _array[].dup);
        }

        inout(DynamicArray!T) opSlice(size_t lo, size_t up) pure inout
        {
            debug(container) writeln("StaticArray<", &this, ">.opSlice()");
            return DynamicArray!T(cast(inout T[]) _array[lo..up].dup);
        }

        @property inout(T*) ptr() pure inout
        {
            return _array.ptr;
        }

        @property size_t length() pure const
        {
            return _array.length;
        }

        size_t opDollar() pure const
        {
            return _array.length;
        }
    }

    @property inout(T[]) array() pure inout
    {
        return _array[];
    }
}
