// Written in the D programming language.

module linalg.storage.regular2d;

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
import linalg.storage.regular1d;

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

/* Regular multidimensional storage */
struct StorageRegular2D(T, StorageOrder storageOrder_,
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
                debugOP.writefln("StorageRegular2D<%X>.this()", &this);
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
        this()(in size_t[2] dim)
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular2D<%X>.this()", &this);
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
            stride = calcStrides!storageOrder(dim);
            _reallocate();
        }

        inout this()(inout ElementType[] array, in size_t[2] dim) pure
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular2D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d", array.ptr, array.length);
                debugOP.writeln("dim = ", dim);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "container<%X> = <%X>, %d",
                    &(this.container),
                    this.container.ptr,
                    this.container.length);
                mixin(debugIndentScope);
            }
            this(array, dim, calcStrides!storageOrder(dim));
        }

        inout this()(inout ElementType[] array,
                     in size_t[2] dim, in size_t[2] stride) pure
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular2D<%X>.this()", &this);
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
                    debugOP.writefln("StorageRegular2D<%X>._reallocate()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    mixin(debugIndentScope);
                    scope(exit) debug debugOP.writefln(
                        "container<%X> = <%X>, %d",
                        &(this.container),
                        this.container.ptr,
                        this.container.length);
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
            debug(slice) debugOP.writeln("slice ", srow, ", ", icol);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(srow.lo, icol)..mapIndex(srow.up, icol)],
                srow.length, stride[1]);
        }

        ref inout auto opIndex(size_t irow, Slice scol) pure inout
        {
            debug(slice) debugOP.writeln("slice ", irow, ", ", scol);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(irow, scol.lo)..mapIndex(irow, scol.up)],
                scol.length, stride[0]);
        }

        ref inout auto opIndex(Slice srow, Slice scol) pure inout
        {
            debug(slice) debugOP.writeln("slice ", srow, ", ", scol);
            return StorageRegular2D!(ElementType, storageOrder,
                                     dynamicSize, dynamicSize)(
                container[mapIndex(srow.lo, scol.lo)
                          ..
                          mapIndex(srow.up, scol.up)],
                [srow.length, scol.length], stride);
        }
    }

    @property auto dup() pure const
    {
        debug(storage)
        {
            debugOP.writefln("StorageRegular2D<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        auto result = StorageRegular2D!(ElementType, storageOrder,
                                        dynamicSize, dynamicSize)(this.dim);
        copy(this, result);
        return result;
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container, dim, stride);
    }

    @property auto byElement() pure
    {
        return linalg.storage.iterators.ByElement!(ElementType, true)(
            container, dim, stride);
    }

    @property auto byElement() pure const
    {
        return linalg.storage.iterators.ByElement!(ElementType, false)(
            container, dim, stride);
    }
}

template isStorageRegular2D(T)
{
    enum bool isStorageRegular2D = isInstanceOf!(StorageRegular2D, T);
}
