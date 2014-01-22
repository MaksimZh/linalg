// Written in the D programming language.

/**
 * Regular two-dimensional storage.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013-2014 Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
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
import linalg.operations.basic;
import linalg.storage.slice;
import linalg.ranges.regular;
import linalg.storage.regular1d;

private // Auxiliary functions
{
    // Calculates strides in data array for dense storage
    size_t[2] calcStrides(StorageOrder storageOrder)(in size_t[2] dim) pure
    {
        static if(storageOrder == StorageOrder.row)
            return [dim[1], 1];
        else static if(storageOrder == StorageOrder.col)
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

/* Regular two-dimensional storage */
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
        enum bool isStatic = !canFind(dimPattern, dynsize);

        static if(isStatic)
            alias ElementType[calcContainerSize(dimPattern)] ContainerType;
        else
            alias ElementType[] ContainerType;
    }

    private // Container, dimensions, strides
    {
        ContainerType _container;

        static if(isStatic)
        {
            enum size_t[2] _dim = dimPattern;
            enum size_t[2] _stride = calcStrides!storageOrder(dimPattern);
        }
        else
        {
            size_t[2] _dim;
            size_t[2] _stride;
        }
    }

    /* Constructors */
    static if(isStatic)
    {
        this()(ElementType[] array) pure
            in
            {
                assert(array.length == _container.length);
            }
        body
        {
            _container = array;
            debug(memory) dfMemCopied(array, _container);
        }
    }
    else
    {
        this()(in size_t[2] dim)
        {
            _dim = dim;
            _stride = calcStrides!storageOrder(dim);
            _reallocate();
        }

        this()(ElementType[] array, in size_t[2] dim) pure
        {
            this(array, dim, calcStrides!storageOrder(dim));
        }

        this()(ElementType[] array,
               in size_t[2] dim, in size_t[2] stride) pure
        {
            debug(memory) dfMemAbandon(_container);
            _container = array;
            _dim = dim;
            _stride = stride;
            debug(memory) dfMemReferred(_container);
        }

        this(Tsource)(auto ref Tsource source) pure
            if(isStorageRegular1D!Tsource)
        {
            static if(storageOrder == StorageOrder.row)
                this(source.container, [1, source.dim], [1, source.stride]);
            else
                this(source.container, [source.dim, 1], [source.stride, 1]);
        }

        this(Tsource)(auto ref Tsource source) pure
            if(isStorageRegular2D!Tsource)
        {
            this(source.container, source.dim, source.stride);
        }
    }

    public // Dimensions and memory
    {
        @property auto container() pure { return _container[]; }
        @property size_t[2] dim() pure const { return _dim; }
        @property size_t[2] stride() pure const { return _stride; }

        @property size_t nrows() pure const { return _dim[0]; }
        @property size_t ncols() pure const { return _dim[1]; }


        /* Test dimensions for compatibility */
        static bool isCompatDim(in size_t[2] dim) pure
        {
            static if(isStatic)
            {
                return dim == dimPattern;
            }
            else
            {
                if(dim.length != rank)
                    return false;
                foreach(i, d; dim)
                    if((d != dimPattern[i]) && (dimPattern[i] != dynsize))
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
                debug(memory) dfMemAbandon(_container);
                _stride = calcStrides!storageOrder(_dim);
                _container = new ElementType[calcContainerSize(_dim)];
                debug(memory) dfMemAllocated(_container);
            }

            void setDim(in size_t[2] dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                _dim = dim;
                _reallocate();
            }
        }
    }

    public // Slices and indices support
    {
        //NOTE: depends on DMD pull-request 443
        private size_t _mapIndex(size_t irow, size_t icol) pure const
        {
            return irow * _stride[0] + icol * _stride[1];
        }

        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure const
        {
            return dim[dimIndex];
        }

        auto opIndex() pure
        {
            debug(slice) debugOP.writeln("slice");
            return StorageRegular2D!(ElementType, storageOrder,
                                           dynsize, dynsize)(
                                               _container[], _dim, _stride);
        }

        ref auto opIndex(size_t irow, size_t icol) pure
        {
            return _container[_mapIndex(irow, icol)];
        }

        ref auto opIndex(Slice srow, size_t icol) pure
        {
            debug(slice) debugOP.writeln("slice ", srow, ", ", icol);
            return StorageRegular1D!(ElementType, dynsize)(
                _container[_mapIndex(srow.lo, icol)
                           ..
                           _mapIndex(srow.upReal - 1, icol) + 1],
                srow.length, _stride[0] * srow.stride);
        }

        ref auto opIndex(size_t irow, Slice scol) pure
        {
            debug(slice) debugOP.writeln("slice ", irow, ", ", scol);
            return StorageRegular1D!(ElementType, dynsize)(
                _container[_mapIndex(irow, scol.lo)
                           ..
                           _mapIndex(irow, scol.upReal - 1) + 1],
                scol.length, _stride[1] * scol.stride);
        }

        ref auto opIndex(Slice srow, Slice scol) pure
        {
            debug(slice) debugOP.writeln("slice ", srow, ", ", scol);
            return StorageRegular2D!(
                             ElementType, storageOrder,
                             dynsize, dynsize)(
                                 _container[_mapIndex(srow.lo, scol.lo)
                                            ..
                                            _mapIndex(srow.upReal - 1,
                                                      scol.upReal - 1)
                                            + 1],
                                 [srow.length, scol.length],
                                 [_stride[0] * srow.stride,
                                  _stride[1] * scol.stride]);
        }
    }

    @property auto dup() pure
    {
        auto result = StorageRegular2D!(ElementType, storageOrder,
                                        dynsize, dynsize)(_dim);
        copy(this, result);
        return result;
    }

    /* Convert to built-in array */
    ElementType[][] opCast() pure const
    {
        return toArray(_container, _dim, _stride);
    }

    public // Ranges
    {
        @property auto byElement() pure
        {
            return ByElement!(ElementType, 2)(
                _container, _dim, _stride);
        }

        @property auto byRow()() pure
        {
            return ByLine!(ElementType, void)(
                _container,
                [_dim[0], _dim[1]],
                [_stride[0], _stride[1]]);
        }

        @property auto byCol()() pure
        {
            return ByLine!(ElementType, void)(
                _container,
                [_dim[1], _dim[0]],
                [_stride[1], _stride[0]]);
        }

        @property auto byRow(ResultType)() pure
        {
            return ByLine!(ElementType, ResultType)(
                _container,
                [_dim[0], _dim[1]],
                [_stride[0], _stride[1]]);
        }

        @property auto byCol(ResultType)() pure
        {
            return ByLine!(ElementType, ResultType)(
                _container,
                [_dim[1], _dim[0]],
                [_stride[1], _stride[0]]);
        }

        @property auto byBlock()(size_t[2] subdim) pure
        {
            return ByBlock!(ElementType, void, storageOrder)(
                _container, _dim, _stride, subdim);
        }

        @property auto byBlock(ResultType)(size_t[2] subdim) pure
        {
            return ByBlock!(ElementType, ResultType, storageOrder)(
                _container, _dim, _stride, subdim);
        }
    }
}

/* Detect whether T is two-dimensional regular storage */
template isStorageRegular2D(T)
{
    enum bool isStorageRegular2D = isInstanceOf!(StorageRegular2D, T);
}

unittest // Type properties
{
    alias StorageRegular2D!(int, StorageOrder.row, 2, 3) Si23r;
    alias StorageRegular2D!(int, StorageOrder.col, 2, 3) Si23c;
    alias StorageRegular2D!(int, StorageOrder.row, 2, dynsize) Si2dr;
    alias StorageRegular2D!(int, StorageOrder.row, dynsize, 3) Sid3r;
    alias StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize) Siddr;

    // dimPattern
    static assert(Si23r.dimPattern == [2, 3]);
    static assert(Si23c.dimPattern == [2, 3]);
    static assert(Si2dr.dimPattern == [2, dynsize]);
    static assert(Sid3r.dimPattern == [dynsize, 3]);
    static assert(Siddr.dimPattern == [dynsize, dynsize]);

    // ElementType
    static assert(is(Si23r.ElementType == int));
    static assert(is(Siddr.ElementType == int));

    // rank
    static assert(Si23r.rank == 2);
    static assert(Siddr.rank == 2);

    // isStatic
    static assert(Si23r.isStatic == true);
    static assert(Si23c.isStatic == true);
    static assert(Si2dr.isStatic == false);
    static assert(Sid3r.isStatic == false);
    static assert(Siddr.isStatic == false);
}

unittest // Constructors, cast
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Constructors, cast");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] a = [1, 2, 3, 4, 5, 6];

    assert(cast(int[][]) StorageRegular2D!(int, StorageOrder.row, 2, 3)(a)
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) StorageRegular2D!(int, StorageOrder.col, 2, 3)(a)
           == [[1, 3, 5],
               [2, 4, 6]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.row, dynsize, dynsize)([2, 3])
           == [[0, 0, 0],
               [0, 0, 0]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.row, dynsize, dynsize)(a, [2, 3])
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.row, dynsize, dynsize)(a, [2, 2], [3, 2])
           == [[1, 3],
               [4, 6]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.row, dynsize, dynsize)(
                   StorageRegular1D!(int, dynsize)(a))
           == [[1, 2, 3, 4, 5, 6]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.col, dynsize, dynsize)(
                   StorageRegular1D!(int, dynsize)(a))
           == [[1],
               [2],
               [3],
               [4],
               [5],
               [6]]);
    assert(cast(int[][]) StorageRegular2D!(
               int, StorageOrder.row, dynsize, dynsize)(
                   StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
                       a, [2, 3]))
           == [[1, 2, 3],
               [4, 5, 6]]);
}

unittest // Dimensions and memory
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Dimensions and memory");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
        src, [2, 3]);
    assert(a.container.ptr == src.ptr);
    assert(a.container == [1, 2, 3, 4, 5, 6]);
    assert(a.dim == [2, 3]);
    assert(a.stride == [3, 1]);
    assert(a.nrows == 2);
    assert(a.ncols == 3);

    assert(StorageRegular2D!(int, StorageOrder.row, 2, 3
               ).isCompatDim([2, 3]) == true);
    assert(StorageRegular2D!(int, StorageOrder.row, 2, 3
               ).isCompatDim([3, 4]) == false);
    assert(StorageRegular2D!(int, StorageOrder.row, 2, dynsize
               ).isCompatDim([2, 3]) == true);
    assert(StorageRegular2D!(int, StorageOrder.row, 2, dynsize
               ).isCompatDim([3, 4]) == false);
    assert(StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize
               ).isCompatDim([2, 3]) == true);
    assert(StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize
               ).isCompatDim([3, 4]) == true);
    assert(a.isCompatDim([2, 3]) == true);
    assert(a.isCompatDim([3, 4]) == true);

    auto b = a.dup;
    assert(b.container.ptr != a.container.ptr);
    assert(b.container == [1, 2, 3, 4, 5, 6]);
    assert(b.dim == [2, 3]);
    assert(b.stride == [3, 1]);

    b.setDim([3, 5]);
    assert(b.dim == [3, 5]);
}

unittest // Indices and slices
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Indices and slices");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    debug debugOP.writeln("Waiting for pull request 443");
}

unittest // Ranges
{
    debug(unittests)
    {
        debugOP.writeln("linalg.storage.regular2d unittest: Ranges");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = StorageRegular2D!(int, StorageOrder.row, 2, 3)(src);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 2, 3, 4, 5, 6]);
        }
        {
            int[][] result = [];
            foreach(r; a.byRow)
                result ~= [cast(int[]) r];
            assert(result == [[1, 2, 3],
                              [4, 5, 6]]);
        }
        {
            int[][] result = [];
            foreach(r; a.byCol)
                result ~= [cast(int[]) r];
            assert(result == [[1, 4],
                              [2, 5],
                              [3, 6]]);
        }
        {
            int[] src1 = [1, 2, 3, 4, 5, 6,
                          7, 8, 9, 10, 11, 12,
                          13, 14, 15, 16, 17, 18,
                          19, 20, 21, 22, 23, 24];
            auto b = StorageRegular2D!(int, StorageOrder.row, 4, 6)(src1);
            int[][][] result = [];
            foreach(r; b.byBlock([2, 3]))
                result ~= [cast(int[][]) r];
            assert(result == [[[1, 2, 3],
                               [7, 8, 9]],
                              [[4, 5, 6],
                               [10, 11, 12]],
                              [[13, 14, 15],
                               [19, 20, 21]],
                              [[16, 17, 18],
                               [22, 23, 24]]]);
        }
    }
    {
        auto a = StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
            src, [2, 3]);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 2, 3, 4, 5, 6]);
        }
        {
            int[][] result = [];
            foreach(r; a.byRow)
                result ~= [cast(int[]) r];
            assert(result == [[1, 2, 3],
                              [4, 5, 6]]);
        }
        {
            int[][] result = [];
            foreach(r; a.byCol)
                result ~= [cast(int[]) r];
            assert(result == [[1, 4],
                              [2, 5],
                              [3, 6]]);
        }
        {
            int[] src1 = [1, 2, 3, 4, 5, 6,
                          7, 8, 9, 10, 11, 12,
                          13, 14, 15, 16, 17, 18,
                          19, 20, 21, 22, 23, 24];
            auto b = StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
                src1, [4, 6]);
            int[][][] result = [];
            foreach(r; b.byBlock([2, 3]))
                result ~= [cast(int[][]) r];
            assert(result == [[[1, 2, 3],
                               [7, 8, 9]],
                              [[4, 5, 6],
                               [10, 11, 12]],
                              [[13, 14, 15],
                               [19, 20, 21]],
                              [[16, 17, 18],
                               [22, 23, 24]]]);
        }
    }
}

version(all) // Old unittests
{
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
    assert(b.container == [0, 1, 2, 3,
                           4, 5, 6, 7,
                           8, 9, 10, 11]);

    //.dup
    auto d = b.dup;
    assert(cast(int[][]) d == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(d.container !is b.container);

    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    foreach(ref t; d.byElement)
        t = 14;
    assert(cast(int[][]) d == [[14, 14, 14, 14],
                               [14, 14, 14, 14],
                               [14, 14, 14, 14]]);

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
                               dynsize, dynsize)([3, 4]);
    assert([a.nrows, a.ncols] == [3, 4]);
    assert(cast(int[][]) a == [[int.init, int.init, int.init, int.init],
                               [int.init, int.init, int.init, int.init],
                               [int.init, int.init, int.init, int.init]]);
    assert(a.container == [int.init, int.init, int.init, int.init,
                           int.init, int.init, int.init, int.init,
                           int.init, int.init, int.init, int.init]);

    auto b = StorageRegular2D!(int, defaultStorageOrder,
                               dynsize, dynsize)(
                                   array(iota(12)), [3, 4]);
    assert([b.nrows, b.ncols] == [3, 4]);
    assert(cast(int[][]) b == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(b.container == [0, 1, 2, 3,
                           4, 5, 6, 7,
                           8, 9, 10, 11]);

    auto c = StorageRegular2D!(int, defaultStorageOrder,
                               dynsize, dynsize)(
                                   array(iota(12)), [2, 2], [8, 3]);
    assert([c.nrows, c.ncols] == [2, 2]);
    assert(cast(int[][]) c == [[0, 3],
                               [8, 11]]);
    assert(c.container == [0, 1, 2, 3,
                           4, 5, 6, 7,
                           8, 9, 10, 11]);

    //.dup
    auto d = b.dup;
    assert(cast(int[][]) d == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    assert(d.container !is b.container);


    // Range
    int[] tmp = [];
    foreach(t; b.byElement)
        tmp ~= t;
    assert(tmp == array(iota(12)));
    foreach(ref t; d.byElement)
        t = 14;
    assert(cast(int[][]) d == [[14, 14, 14, 14],
                               [14, 14, 14, 14],
                               [14, 14, 14, 14]]);

    // Indices
    assert(b[0, 0] == 0);
    assert(b[1, 2] == 6);
    assert(b[2, 3] == 11);

    assert(c[0, 0] == 0);
    assert(c[0, 1] == 3);
    assert(c[1, 1] == 11);
}
}
