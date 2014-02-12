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

debug import linalg.aux.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.aux.types;
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
struct StorageRegular2D(T)
{
    enum size_t nrows_ = 2;
    enum size_t ncols_ = 2;

    public // Check and process parameters
    {
        enum size_t[] dimPattern = [nrows_, ncols_];

        alias T ElementType; // Type of the array elements
        public enum uint rank = 2; // Number of dimensions
        enum StorageOrder storageOrder = defaultStorageOrder;

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
