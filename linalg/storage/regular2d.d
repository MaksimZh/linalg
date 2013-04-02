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
import linalg.ranges.regular;
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

        inout this(Tsource)(ref inout Tsource source) pure
            if(isStorageRegular1D!Tsource)
        {
            debug(storage)
            {
                debugOP.writefln("StorageRegular2D<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("source.container = <%X>, %d",
                                 source.container.ptr,
                                 source.container.length);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "container<%X> = <%X>, %d",
                    &(this.container),
                    this.container.ptr,
                    this.container.length);
                mixin(debugIndentScope);
            }
            container = source.container;
            static if(storageOrder == StorageOrder.rowMajor)
            {
                this.dim = [1, source.length];
                this.stride = [1, source.stride];
            }
            else
            {
                this.dim = [source.length, 1];
                this.stride = [source.stride, 1];
            }
        }
    }

    public // Dimensions and memory
    {
        @property size_t nrows() pure const { return dim[0]; }
        @property size_t ncols() pure const { return dim[1]; }

        /* Test dimensions for compatibility */
        bool isCompatDim(in size_t[] dim) pure
        {
            static if(isStatic)
            {
                return this.dim == dim;
            }
            else
            {
                if(dim.length != rank)
                    return false;
                foreach(i, d; dim)
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

            void setDim(in size_t[2] dim) pure
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
        package size_t mapIndex(size_t irow, size_t icol) pure const
        {
            return irow * stride[0] + icol * stride[1];
        }

        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure const
        {
            return dim[dimIndex];
        }

        ref inout auto opIndex() pure inout
        {
            debug(slice) debugOP.writeln("slice");
            return StorageRegular2D!(ElementType, storageOrder,
                                     dynamicSize, dynamicSize)(
                                         container[], dim, stride);
        }

        ref inout auto opIndex(size_t irow, size_t icol) pure inout
        {
            return container[mapIndex(irow, icol)];
        }

        ref inout auto opIndex(Slice srow, size_t icol) pure inout
        {
            debug(slice) debugOP.writeln("slice ", srow, ", ", icol);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(srow.lo, icol)
                          ..
                          mapIndex(srow.upReal - 1, icol) + 1],
                srow.length, stride[0] * srow.stride);
        }

        ref inout auto opIndex(size_t irow, Slice scol) pure inout
        {
            debug(slice) debugOP.writeln("slice ", irow, ", ", scol);
            return StorageRegular1D!(ElementType, dynamicSize)(
                container[mapIndex(irow, scol.lo)
                          ..
                          mapIndex(irow, scol.upReal - 1) + 1],
                scol.length, stride[1] * scol.stride);
        }

        ref inout auto opIndex(Slice srow, Slice scol) pure inout
        {
            debug(slice) debugOP.writeln("slice ", srow, ", ", scol);
            return StorageRegular2D!(ElementType, storageOrder,
                                     dynamicSize, dynamicSize)(
                                         container[mapIndex(srow.lo, scol.lo)
                                                   ..
                                                   mapIndex(srow.upReal - 1,
                                                            scol.upReal - 1)
                                                   + 1],
                                         [srow.length, scol.length],
                                         [stride[0] * srow.stride,
                                          stride[1] * scol.stride]);
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

    public // Ranges
    {
        @property auto byElement() pure
        {
            return ByElement!(ElementType, 2, true)(
                container, dim, stride);
        }

        @property auto byElement() pure const
        {
            return ByElement!(ElementType, 2, false)(
                container, dim, stride);
        }

        @property auto byRow()() pure
        {
            return ByLine!(ElementType, void, true)(
                container,
                dim[0], stride[0],
                dim[1], stride[1]);
        }

        @property auto byRow()() pure const
        {
            return ByLine!(ElementType, void, false)(
                container,
                dim[0], stride[0],
                dim[1], stride[1]);
        }

        @property auto byCol()() pure
        {
            return ByLine!(ElementType, void, true)(
                container,
                dim[1], stride[1],
                dim[0], stride[0]);
        }

        @property auto byCol()() pure const
        {
            return ByLine!(ElementType, void, false)(
                container,
                dim[1], stride[1],
                dim[0], stride[0]);
        }

        @property auto byRow(ResultType)() pure
        {
            return ByLine!(ElementType, void, true)(
                container,
                dim[0], stride[0],
                dim[1], stride[1]);
        }

        @property auto byRow(ResultType)() pure const
        {
            return ByLine!(ElementType, ResultType, false)(
                container,
                dim[0], stride[0],
                dim[1], stride[1]);
        }

        @property auto byCol(ResultType)() pure
        {
            return ByLine!(ElementType, ResultType, true)(
                container,
                dim[1], stride[1],
                dim[0], stride[0]);
        }

        @property auto byCol(ResultType)() pure const
        {
            return ByLine!(ElementType, ResultType, false)(
                container,
                dim[1], stride[1],
                dim[0], stride[0]);
        }
    }

    @property auto data() pure inout
    {
        return container[];
    }
}

template isStorageRegular2D(T)
{
    enum bool isStorageRegular2D = isInstanceOf!(StorageRegular2D, T);
}

unittest // Static
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Static");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    // Constructors
    auto b = StorageRegular2D!(int, defaultStorageOrder,
                               3, 4)(
                                   array(iota(12)));
    assert([b.nrows, b.ncols] == [3, 4]);
    assert(cast(int[][]) b == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(b.data == [0, 1, 2, 3,
                      4, 5, 6, 7,
                      8, 9, 10, 11]);

    immutable auto ib = StorageRegular2D!(int, defaultStorageOrder,
                                          3, 4)(
                                              array(iota(12)));
    assert([ib.nrows, ib.ncols] == [3, 4]);
    assert(cast(int[][]) ib == [[0, 1, 2, 3],
                                [4, 5, 6, 7],
                                [8, 9, 10, 11]]);
    assert(ib.data == [0, 1, 2, 3,
                       4, 5, 6, 7,
                       8, 9, 10, 11]);

    //.dup
    auto d = b.dup;
    assert(cast(int[][]) d == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(d.data !is b.data);

    auto d1 = ib.dup;
    assert(cast(int[][]) d1 == [[0, 1, 2, 3],
                                [4, 5, 6, 7],
                                [8, 9, 10, 11]]);
    assert(d1.data !is ib.data);

    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    tmp = [];
    foreach(t; ib.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    foreach(ref t; d.byElement)
        t = 14;
    assert(cast(int[][]) d == [[14, 14, 14, 14],
                               [14, 14, 14, 14],
                               [14, 14, 14, 14]]);
    foreach(ref t; ib.byElement)
        t = 4;
    assert(cast(int[][]) ib == [[0, 1, 2, 3],
                                [4, 5, 6, 7],
                                [8, 9, 10, 11]]);

    // Indices
    assert(b[0, 0] == 0);
    assert(b[1, 2] == 6);
    assert(b[2, 3] == 11);
}

unittest // Dynamic
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Dynamic");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    // Constructors
    auto a = StorageRegular2D!(int, defaultStorageOrder,
                               dynamicSize, dynamicSize)([3, 4]);
    assert([a.nrows, a.ncols] == [3, 4]);
    assert(cast(int[][]) a == [[int.init, int.init, int.init, int.init],
                               [int.init, int.init, int.init, int.init],
                               [int.init, int.init, int.init, int.init]]);
    assert(a.data == [int.init, int.init, int.init, int.init,
                      int.init, int.init, int.init, int.init,
                      int.init, int.init, int.init, int.init]);

    auto b = StorageRegular2D!(int, defaultStorageOrder,
                               dynamicSize, dynamicSize)(
                                   array(iota(12)), [3, 4]);
    assert([b.nrows, b.ncols] == [3, 4]);
    assert(cast(int[][]) b == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(b.data == [0, 1, 2, 3,
                      4, 5, 6, 7,
                      8, 9, 10, 11]);

    auto c = StorageRegular2D!(int, defaultStorageOrder,
                               dynamicSize, dynamicSize)(
                                   array(iota(12)), [2, 2], [8, 3]);
    assert([c.nrows, c.ncols] == [2, 2]);
    assert(cast(int[][]) c == [[0, 3],
                               [8, 11]]);
    assert(c.data == [0, 1, 2, 3,
                      4, 5, 6, 7,
                      8, 9, 10, 11]);

    immutable auto ia = StorageRegular2D!(int, defaultStorageOrder,
                                          dynamicSize, dynamicSize)([3, 4]);
    assert([ia.nrows, ia.ncols] == [3, 4]);
    assert(cast(int[][]) ia == [[int.init, int.init, int.init, int.init],
                                [int.init, int.init, int.init, int.init],
                                [int.init, int.init, int.init, int.init]]);
    assert(ia.data == [int.init, int.init, int.init, int.init,
                       int.init, int.init, int.init, int.init,
                       int.init, int.init, int.init, int.init]);

    immutable auto ib = StorageRegular2D!(int, defaultStorageOrder,
                                          dynamicSize, dynamicSize)(
                                              array(iota(12)), [3, 4]);
    assert([ib.nrows, ib.ncols] == [3, 4]);
    assert(cast(int[][]) ib == [[0, 1, 2, 3],
                                [4, 5, 6, 7],
                                [8, 9, 10, 11]]);
    assert(ib.data == [0, 1, 2, 3,
                       4, 5, 6, 7,
                       8, 9, 10, 11]);

    immutable auto ic = StorageRegular2D!(int, defaultStorageOrder,
                                          dynamicSize, dynamicSize)(
                                              array(iota(12)), [2, 2], [8, 3]);
    assert([ic.nrows, ic.ncols] == [2, 2]);
    assert(cast(int[][]) ic == [[0, 3],
                                [8, 11]]);
    assert(ic.data == [0, 1, 2, 3,
                       4, 5, 6, 7,
                       8, 9, 10, 11]);

    //.dup
    auto d = b.dup;
    assert(cast(int[][]) d == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(d.data !is b.data);

    auto d1 = ic.dup;
    assert(cast(int[][]) d1 == [[0, 3],
                                [8, 11]]);
    assert(d1.data !is ib.data);

    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    tmp = [];
    foreach(t; ib.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    foreach(ref t; d.byElement)
        t = 14;
    assert(cast(int[][]) d == [[14, 14, 14, 14],
                               [14, 14, 14, 14],
                               [14, 14, 14, 14]]);
    foreach(ref t; ib.byElement)
        t = 4;
    assert(cast(int[][]) ib == [[0, 1, 2, 3],
                                [4, 5, 6, 7],
                                [8, 9, 10, 11]]);

    // Indices
    assert(b[0, 0] == 0);
    assert(b[1, 2] == 6);
    assert(b[2, 3] == 11);

    assert(c[0, 0] == 0);
    assert(c[0, 1] == 3);
    assert(c[1, 1] == 11);
}
