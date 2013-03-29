// Written in the D programming language.

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
import linalg.storage.mdarray;
import linalg.storage.operations;
import linalg.storage.slice;
import linalg.storage.iterators;

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

/* Regular multidimensional storage */
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

    package // Container, dimensions, strides
    {
        ContainerType container;

        static if(isStatic)
        {
            enum size_t dim = dimPattern;
            enum size_t stride = 1;
        }
        else
        {
            size_t dim;
            size_t stride;
        }
    }

    /* Constructors */
    static if(isStatic)
    {
        inout this()(inout ElementType[] array) pure
            in
            {
                assert(array.length == container.length);
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
                    "container = <%X>, %d",
                    this.container.ptr,
                    this.container.length);
                mixin(debugIndentScope);
            }
            container = array;
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
                    "container = <%X>, %d",
                    this.container.ptr,
                    this.container.length);
                mixin(debugIndentScope);
            }
            this.dim = dim;
            stride = 1;
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
                    "container<%X> = <%X>, %d",
                    &(this.container),
                    this.container.ptr,
                    this.container.length);
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
                    "container<%X> = <%X>, %d",
                    &(this.container),
                    this.container.ptr,
                    this.container.length);
                mixin(debugIndentScope);
            }
            container = array;
            this.dim = dim;
            this.stride = stride;
        }
    }

    public // Dimensions and memory
    {
        @property size_t length() pure const { return dim; }

        /* Test dimensions for compatibility */
        bool isCompatDim(in size_t dim) pure
        {
            static if(isStatic)
            {
                return dim == dimPattern;
            }
            else
            {
                return (dim == dimPattern) || (dimPattern == dynamicSize);
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
                        "container<%X> = <%X>, %d",
                        &(this.container),
                        this.container.ptr,
                        this.container.length);
                    mixin(debugIndentScope);
                }
                stride = 1;
                container = new ElementType[dim];
            }

            void setDim(in size_t dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                this.dim = dim;
                _reallocate();
            }
        }
    }

    public // Slices and indices support
    {
        //NOTE: depends on DMD pull-request 443
        package size_t mapIndex(size_t i) pure const
        {
            return i * stride;
        }

        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure const
        {
            static assert(dimIndex == 0);
            return dim;
        }

        ref inout auto opIndex() pure inout
        {
            debug(slice) debugOP.writeln("slice");
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[], length, stride);
        }

        ref inout auto opIndex(size_t i) pure inout
        {
            return container[mapIndex(i)];
        }

        ref inout auto opIndex(Slice s) pure inout
        {
            debug(slice) debugOP.writeln("slice ", s);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(s.lo)..mapIndex(s.up)], s.length, stride);
        }
    }

    /* Makes copy of the data and returns new storage referring to it.
       The storage returned is always dynamic.
    */
    @property auto dup() pure const
    {
        debug(storage)
        {
            debugOP.writefln("StorageRegular1D<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        auto result = StorageRegular1D!(ElementType, dynamicSize)(this.dim);
        copy(this, result);
        return result;
    }

    ElementType[] opCast() pure const
    {
        return toArray(container, dim, stride);
    }

    @property auto byElement() pure
    {
        return ByElement!(ElementType, 1, true)(container,
                                                dim,
                                                stride);
    }

    @property auto byElement() pure const
    {
        return ByElement!(ElementType, 1, false)(container,
                                                 dim,
                                                 stride);
    }

    @property auto data() pure inout
    {
        return container[];
    }
}

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
    assert(b.data == [0, 1, 2, 3]);

    immutable auto ib = StorageRegular1D!(int, 4)([0, 1, 2, 3]);
    assert(ib.length == 4);
    assert(cast(int[]) ib == [0, 1, 2, 3]);
    assert(ib.data == [0, 1, 2, 3]);

    // .dup
    auto d = b.dup;
    assert(cast(int[]) d == [0, 1, 2, 3]);
    assert(d.data !is b.data);

    auto d1 = ib.dup;
    assert(cast(int[]) d1 == [0, 1, 2, 3]);
    assert(d1.data !is ib.data);

    // Iterator
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
    assert(a.data == [int.init, int.init, int.init, int.init]);

    auto b = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3]);
    assert(b.length == 4);
    assert(cast(int[]) b == [0, 1, 2, 3]);
    assert(b.data == [0, 1, 2, 3]);

    auto c = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3], 2, 3);
    assert(c.length == 2);
    assert(cast(int[]) c == [0, 3]);
    assert(c.data == [0, 1, 2, 3]);

    immutable auto ia = StorageRegular1D!(int, dynamicSize)(4);
    assert(ia.length == 4);
    assert(cast(int[]) ia == [int.init, int.init, int.init, int.init]);
    assert(ia.data == [int.init, int.init, int.init, int.init]);

    immutable auto ib = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3]);
    assert(ib.length == 4);
    assert(cast(int[]) ib == [0, 1, 2, 3]);
    assert(ib.data == [0, 1, 2, 3]);

    immutable auto ic = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3], 2, 3);
    assert(ic.length == 2);
    assert(cast(int[]) ic == [0, 3]);
    assert(ic.data == [0, 1, 2, 3]);

    // .dup
    auto d = b.dup;
    assert(cast(int[]) d == [0, 1, 2, 3]);
    assert(d.data !is b.data);
    auto d1 = ic.dup;
    assert(cast(int[]) d1 == [0, 3]);
    assert(d1.data !is ic.data);

    // Iterator
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
