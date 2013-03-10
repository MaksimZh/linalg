// Written in the D programming language.

module linalg.storage.dense2d;

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

private // Auxiliary functions
{
    // Calculates strides in data array for dense storage
    size_t[2] calcStrides(StorageOrder storageOrder)(in size_t[2] dim) pure
    {
        static if(storageOrder == StorageOrder.rowMajor)
            return [dim[1], 1];
        else static if(storageOrder == StorageOrder.colMajor)
            return [1, dim[0]];
        else
            static assert(false);
    }

    // Calculates container size for dense storage
    size_t calcContainerSize(in size_t[2] dim) pure
    {
        return dim[0] * dim[1];
    }

    // Convert storage to built-in multidimensional array
    auto toArray(T)(in T[] container,
                    in size_t[2] dim,
                    in size_t[2] stride) pure
    {
        auto result = new T[][](dim[0], dim[1]);
        foreach(i; 0..dim[0])
            foreach(j; 0..dim[1])
                result[i][j] = container[i*stride[0] + j*stride[1]];
        return result;
    }

    unittest // toArray
    {
        assert(toArray(array(iota(12)), [3, 4], [4, 1])
               == [[0, 1, 2, 3],
                   [4, 5, 6, 7],
                   [8, 9, 10, 11]]);
    }
}

/* Dense multidimensional storage */
struct StorageDense2D(T, StorageOrder storageOrder_,
                      size_t nrows_, size_t ncols_)
{
    public // Check and process parameters
    {
        enum size_t[] dimPattern = [nrows_, ncols_];

        alias T ElementType; // Type of the array elements
        public enum uint rank = 2; // Number of dimensions
        enum StorageOrder storageOrder = storageOrder_;

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = !canFind(dimPattern, dynamicSize);
        enum bool isResizeable = !isStatic;

        static if(isStatic)
            alias ElementType[calcContainerSize(dimPattern)] ContainerType;
        else
            alias ElementType[] ContainerType;
    }

    package // Container, dimensions, strides
    {
        ContainerType container;

        static if(isStatic)
        {
            enum size_t[2] dim = dimPattern;
            enum size_t[2] stride = calcStrides!storageOrder(dim);
        }
        else
        {
            size_t[2] dim;
            size_t[2] stride;
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
                indent.writefln("StorageDense2D<%X>.this()", &this);
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
        this()(in size_t[2] dim)
        {
            debug(storage)
            {
                indent.writefln("StorageDense2D<%X>.this()", &this);
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
            stride = calcStrides!storageOrder(dim);
            _reallocate();
        }

        inout this()(inout ElementType[] array, in size_t[2] dim) pure
        {
            debug(storage)
            {
                indent.writefln("StorageDense2D<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d", array.ptr, array.length);
                indent.writeln("dim = ", dim);
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
            this(array, dim, calcStrides!storageOrder(dim));
        }

        inout this()(inout ElementType[] array,
                     in size_t[2] dim, in size_t[2] stride) pure
        {
            debug(storage)
            {
                indent.writefln("StorageDense2D<%X>.this()", &this);
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
        @property size_t nrows() pure const { return dim[0]; }
        @property size_t ncols() pure const { return dim[1]; }

        /* Test dimensions for compatibility */
        bool isCompatDim(in size_t[] dim_) pure
        {
            static if(isStatic)
            {
                return dim == dim_;
            }
            else
            {
                if(dim.length != rank)
                    return false;
                foreach(i, d; dim_)
                    if((d != dimPattern[i]) && (dimPattern[i] != dynamicSize))
                        return false;
                return true;
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
                    indent.writefln("StorageDense2D<%X>._reallocate()", &this);
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
                stride = calcStrides!storageOrder(dim);
                container = new ElementType[calcContainerSize(dim)];
            }

            void setDim(in size_t[2] dim_) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                dim = dim_;
                _reallocate();
            }
        }
    }

    public // Slices and indices support
    {
        package size_t mapIndex(size_t irow, size_t icol) pure const
        {
            return irow * stride[0] + icol * stride[1];
        }

        Slice opSlice(size_t dimIndex)(size_t lo, size_t up) pure const
        {
            return Slice(lo, up);
        }

        size_t opDollar(size_t dimIndex)() pure const
        {
            return dim[dimIndex];
        }

        ref inout auto opIndex(size_t irow, size_t icol) pure inout
        {
            return container[mapIndex(irow, icol)];
        }

        ref inout auto opIndex(Slice srow, size_t icol) pure inout
        {
            debug(slice) writeln("slice ", srow, ", ", icol);
            return container[mapIndex(srow.lo, icol)]; //FIXME
        }

        ref inout auto opIndex(size_t irow, Slice scol) pure inout
        {
            debug(slice) writeln("slice ", irow, ", ", scol);
            return container[mapIndex(irow, scol.lo)]; //FIXME
        }

        ref inout auto opIndex(Slice srow, Slice scol) pure inout
        {
            debug(slice) writeln("slice ", srow, ", ", scol);
            return container[mapIndex(srow.lo, scol.lo)]; //FIXME
        }
    }

    @property StorageDense2D dup() pure const
    {
        auto result = StorageDense2D(this.dim);
        copy2D(this.container, this.stride,
               result.container, result.stride,
               result.dim);
        return result;
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container, dim, stride);
    }
}

template isStorageDense2D(T)
{
    enum bool isStorageDense2D = isInstanceOf!(StorageDense2D, T);
}

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

void copy2D(T)(in T[] source, in size_t[2] sStride,
               T[] dest, in size_t[2] dStride,
               in size_t[2] dim) pure
{
    debug(copy)
    {
        indent.writeln("copy2D");
        indent.add();
        indent.writefln("source = <%X>, %d", source.ptr, source.length);
        indent.writeln("sStride = ", sStride);
        indent.writefln("dest = <%X>, %d", dest.ptr, dest.length);
        indent.writeln("dStride = ", dStride);
        indent.writeln("dim = ", dim);
        indent.writeln("...");
        indent.add();
        scope(exit)
            debug
            {
                indent.rem();
                indent.rem();
            }
    }
    auto isource = ByElement!(T, false)(source, dim, sStride);
    auto idest = ByElement!(T, true)(dest, dim, dStride);
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
}

unittest
{
    auto a = StorageDense2D!(int, StorageOrder.rowMajor,
                             dynamicSize, dynamicSize)([4, 4]);
}
