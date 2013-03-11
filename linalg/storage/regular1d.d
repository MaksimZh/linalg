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

    /* Constructors and destructor */
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
                indent.writefln("StorageRegular1D<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d", array.ptr, array.length);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("container = <%X>, %d",
                                        this.container.ptr,
                                        this.container.length);
                        indent.rem();
                    }
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
                indent.writefln("StorageRegular1D<%X>.this()", &this);
                indent.add();
                indent.writeln("dim = ", dim);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("container = <%X>, %d",
                                        this.container.ptr,
                                        this.container.length);
                        indent.rem();
                    }
            }
            this.dim = dim;
            stride = 1;
            _reallocate();
        }

        inout this()(inout ElementType[] array) pure
        {
            debug(storage)
            {
                indent.writefln("StorageRegular1D<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d", array.ptr, array.length);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("container<%X> = <%X>, %d",
                                        &(this.container),
                                        this.container.ptr,
                                        this.container.length);
                        indent.rem();
                    }
            }
            this(array, array.length, 1);
        }

        inout this()(inout ElementType[] array,
                     size_t dim, size_t stride) pure
        {
            debug(storage)
            {
                indent.writefln("StorageRegular1D<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d",
                                array.ptr, array.length);
                indent.writeln("dim = ", dim);
                indent.writeln("stride = ", stride);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("container<%X> = <%X>, %d",
                                        &(this.container),
                                        this.container.ptr,
                                        this.container.length);
                        indent.rem();
                    }
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
                    indent.writefln("StorageRegular1D<%X>._reallocate()", &this);
                    indent.add();
                    indent.writeln("...");
                    indent.add();
                    scope(exit)
                        debug
                        {
                            indent.rem();
                            indent.writefln("container<%X> = <%X>, %d",
                                            &(this.container),
                                            this.container.ptr,
                                            this.container.length);
                            indent.rem();
                        }
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
        package size_t mapIndex(size_t i) pure const
        {
            return i * stride;
        }

        Slice opSlice(size_t dimIndex)(size_t lo, size_t up) pure const
        {
            static assert(dimIndex == 0);
            return Slice(lo, up);
        }

        size_t opDollar(size_t dimIndex)() pure const
        {
            static assert(dimIndex == 0);
            return dim;
        }

        ref inout auto opIndex(size_t i) pure inout
        {
            return container[mapIndex(i)];
        }

        ref inout auto opIndex(Slice s) pure inout
        {
            debug(slice) writeln("slice ", s);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(s.lo)..mapIndex(s.up)], s.length, stride);
        }
    }

    /* Makes copy of the data and returns new storage referring to it.
       The storage returned is always dynamic.
    */
    @property auto dup() pure const
    {
        auto result = StorageRegular1D(this.dim);
        copy(this, result);
        return result;
    }

    ElementType[] opCast() pure const
    {
        return toArray(container, dim, stride);
    }

    @property auto byElement() pure
    {
        return ByElement!(ElementType, true)(container,
                                             dim,
                                             stride);
    }

    @property auto byElement() pure const
    {
        return ByElement!(ElementType, false)(container,
                                              dim,
                                              stride);
    }
}

template isStorageRegular1D(T)
{
    enum bool isStorageRegular1D = isInstanceOf!(StorageRegular1D, T);
}

/* Iterator */
struct ByElement(ElementType, bool mutable = true)
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

    @property bool empty() pure const { return _ptr < _ptrFin; }
    static if(mutable)
        @property ref ElementType front() pure { return *_ptr; }
    else
        @property ElementType front() pure { return *_ptr; }
    void popFront() pure { _ptr += _stride; }
}

unittest // Static
{
    //auto a = StorageRegular1D!(int, 4);
}

unittest // Dynamic
{
    debug writeln("linalg.storage.regular1d unittest-begin");
    { // Constructors
        auto a = StorageRegular1D!(int, dynamicSize)(4);
        auto b = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3]);
        auto c = StorageRegular1D!(int, dynamicSize)([0, 1, 2, 3], 2, 3);
    }
    debug writeln("linalg.storage.regular1d unittest-end");
}
