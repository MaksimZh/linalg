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
        this(size_t length)
        {
            _pCounter = new uint;
            *_pCounter = 1;
            debug(refcount)
                writeln("DynamicArray<", &this, ">.this()",
                        " counter<", _pCounter, "> = 1");
            _array.length = length;
        }

        this(T[] array) pure
        {
            _pCounter = new uint;
            *_pCounter = 1;
            debug(refcount)
                writeln("DynamicArray<", &this, ">.this()",
                        " counter<", _pCounter, "> = 1");
            _array = array;
        }

        private inout this(inout uint* pCounter, inout T[] array) pure
        {
            _pCounter = pCounter;
            debug(refcount)
                writeln("DynamicArray<", &this, ">.this()",
                        " counter<", _pCounter, "> = ", *_pCounter);
            _array = array;
        }
    }

    @property bool isInitialized() pure const { return _pCounter !is null; }

    public // Reference counting interface
    {
        @property uint refNumber() pure const { return *_pCounter; }
        @property bool isShared() pure const { return *_pCounter > 1; }

        void addRef() pure
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            ++*_pCounter;
            debug(refcount)
                writeln("DynamicArray<", &this, ">.addRef()",
                        " counter<", _pCounter, "> = ", *_pCounter);
        }

        void remRef() pure
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            --*_pCounter;
            debug(refcount)
                writeln("DynamicArray<", &this, ">.remRef()",
                        " counter<", _pCounter, "> = ", *_pCounter);
        }
    }

    public // Slice and index interface
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

        inout(DynamicArray) opSlice(size_t lo, size_t up) pure inout
            in
            {
                assert(isInitialized, "Container is not initialized");
            }
        body
        {
            return DynamicArray(_pCounter, _array[lo..up]);
        }
    }

    inout(T[]) array() pure inout
        in
        {
            assert(isInitialized, "Container is not initialized");
        }
    body
    {
        return _array;
    }
}

unittest
{
    DynamicArray!int a;
    a = DynamicArray!int([0, 1, 2, 3, 4]);
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
}

template StaticArray(T, size_t size)
{
    alias T[size] StaticArray;
}
