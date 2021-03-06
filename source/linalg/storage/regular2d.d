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

debug import linalg.misc.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.misc.types;
import linalg.storage.slice;
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
    auto toArray(T)(T[] container,
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
            debug(linalg_memory) dfMemCopied(array, _container);
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
            debug(linalg_memory) dfMemAbandon(_container);
            _container = array;
            _dim = dim;
            _stride = stride;
            debug(linalg_memory) dfMemReferred(_container);
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
                debug(linalg_memory) dfMemAbandon(_container);
                _stride = calcStrides!storageOrder(_dim);
                _container = new ElementType[calcContainerSize(_dim)];
                debug(linalg_memory) dfMemAllocated(_container);
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
            return StorageRegular1D!(ElementType, dynsize)(
                _container[_mapIndex(srow.lo, icol)
                           ..
                           _mapIndex(srow.upReal - 1, icol) + 1],
                srow.length, _stride[0] * srow.stride);
        }

        ref auto opIndex(size_t irow, Slice scol) pure
        {
            return StorageRegular1D!(ElementType, dynsize)(
                _container[_mapIndex(irow, scol.lo)
                           ..
                           _mapIndex(irow, scol.upReal - 1) + 1],
                scol.length, _stride[1] * scol.stride);
        }

        ref auto opIndex(Slice srow, Slice scol) pure
        {
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
    
    /* Convert to built-in array */
    ElementType[][] opCast() pure
    {
        return toArray(_container, _dim, _stride);
    }

    public // Ranges
    {
        @property auto byElement() pure
        {
            return ByElement!ElementType(
                _container.ptr, _dim, _stride);
        }

        @property auto byRow() pure
        {
            return ByLine!ElementType(
                _container.ptr,
                [_dim[0], _dim[1]],
                [_stride[0], _stride[1]]);
        }

        @property auto byCol() pure
        {
            return ByLine!ElementType(
                _container.ptr,
                [_dim[1], _dim[0]],
                [_stride[1], _stride[0]]);
        }
        
        @property auto byBlock(size_t[2] subdim) pure
        {
            return ByBlock!(ElementType, storageOrder)(
                _container.ptr, _dim, _stride, subdim);
        }
    }
}

/* Detect whether T is two-dimensional regular storage */
template isStorageRegular2D(T)
{
    enum bool isStorageRegular2D = isInstanceOf!(StorageRegular2D, T);
}

/*
 * By-element iteration that goes like in folded loops:
 * foreach(i0; 0..dim0){ foreach(i1; 0..dim1){ ... }}
 */
struct ByElement(ElementType)
{
    private
    {
        ElementType* _ptr;
        const size_t[2] _dim;
        const size_t[2] _stride;

        size_t _i, _j;
        bool _empty;
    }

    this(ElementType* ptr, size_t[2] dim, size_t[2] stride) pure
    {
        _ptr = ptr;
        _dim = dim;
        _stride = stride;
        _i = 0;
        _j = 0;
        _empty = false;
    }

    @property bool empty() pure  { return _empty; }
    @property ref ElementType front() pure { return *_ptr; }

    void popFront() pure
    {
        if(_j == _dim[1] - 1)
        {
            _ptr -= _stride[1] * _j;
            _j = 0;
            if(_i == _dim[0] - 1)
            {
                _empty = true;
            }
            else
            {
                _ptr += _stride[0];
                ++_i;
            }
        }
        else
        {
            _ptr += _stride[1];
            ++_j;
        }
    }
}

/*
 * Iteration by row or column (depending on strides)
 */
struct ByLine(ElementType)
{
    private
    {
        ElementType* _ptr;
        const size_t _dimExt;
        const size_t _strideExt;
        const size_t _dimInt;
        const size_t _strideInt;

        const ElementType* _ptrFin;
    }

    this(ElementType* ptr, in size_t[2] dim, in size_t[2] stride) pure
    {
        _ptr = ptr;
        _dimExt = dim[0];
        _strideExt = stride[0];
        _dimInt = dim[1];
        _strideInt = stride[1];
        _ptrFin = ptr + dim[0] * stride[0];
    }

    @property bool empty() pure  { return _ptr >= _ptrFin; }

    @property auto front() pure
    {
        return StorageRegular1D!(ElementType, dynsize)(
            _ptr[0..((_dimInt - 1) * _strideInt + 1)],
            _dimInt, _strideInt);
    }

    void popFront() pure { _ptr += _strideExt; }
}

/*
 * Iteration by matrix block
 */
struct ByBlock(ElementType, StorageOrder storageOrder)
{
    private
    {
        ElementType* _ptr;
        const size_t[2] _dim;
        const size_t[2] _stride;
        const size_t[2] _substride;
        const size_t[2] _subdim;
        const size_t _len;

        size_t _i, _j;
        bool _empty;
    }

    this(ElementType* ptr, size_t[2] dim, size_t[2] stride,
         size_t[2] subdim) pure
        in
        {
            assert(dim[0] % subdim[0] == 0);
            assert(dim[1] % subdim[1] == 0);
        }
    body
    {
        _ptr = ptr;
        _substride = stride;
        _subdim = subdim;
        _dim = [dim[0] / subdim[0], dim[1] / subdim[1]];
        _stride = [stride[0] * subdim[0], stride[1] * subdim[1]];
        _len = (_subdim[0] - 1) * _substride[0]
            + (_subdim[1] - 1) * _substride[1]
            + 1;
        _i = 0;
        _j = 0;
        _empty = false;
    }

    @property bool empty() pure  { return _empty; }

    @property auto front() pure
    {
        return StorageRegular2D!(ElementType, storageOrder,
                                 dynsize, dynsize)(
                                     _ptr[0.._len],
                                     _subdim, _substride);
    }

    void popFront() pure
    {
        if(_j == _dim[1] - 1)
        {
            _ptr -= _stride[1] * _j;
            _j = 0;
            if(_i == _dim[0] - 1)
            {
                _empty = true;
            }
            else
            {
                _ptr += _stride[0];
                ++_i;
            }
        }
        else
        {
            _ptr += _stride[1];
            ++_j;
        }
    }
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
    debug mixin(debugUnittestBlock("Constructors, cast"));
        
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
    debug mixin(debugUnittestBlock("Dimensions and memory"));
        
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

    //TODO: test setDim
}

unittest // Indices and slices
{
    debug mixin(debugUnittestBlock("Indices and slices"));
    debug debugOP.writeln("Waiting for pull request 443");
}

unittest // Ranges
{
    debug mixin(debugUnittestBlock("Ranges"));
        
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
