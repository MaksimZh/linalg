// Written in the D programming language.

module linalg.storage.dense2d;

import std.algorithm;
import std.traits;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.types;
import linalg.storage.container;
import linalg.storage.slice;
import linalg.storage.mdarray;
import linalg.storage.operations;

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

        static if(isStatic)
            alias StaticArray!(ElementType, calcContainerSize(dimPattern))
                ContainerType;
        else
            alias DynamicArray!ElementType ContainerType;
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
        inout this(inout ElementType[] array) pure
            in
            {
                assert(array.length == container.length);
            }
        body
        {
            container = ContainerType(array);
            debug writeln("StorageDense2D<", &this, ">.this()",
                          " container<", &container, ">.ptr = ",
                          container.ptr);
        }
    }
    else
    {
        this(in size_t[2] dim_)
        {
            container = ContainerType(calcContainerSize(dim));
            dim = dim_;
            stride = calcStrides!storageOrder(dim);
            debug writeln("StorageDense2D<", &this, ">.this()",
                          " container<", &container, ">.ptr = ",
                          container.ptr);
        }

        inout this(inout ContainerType container_,
                   in size_t[2] dim_, in size_t[2] stride_) pure
        {
            container = container_;
            dim = dim_;
            stride = stride_;
            debug writeln("StorageDense2D<", &this, ">.this()",
                          " container<", &container, ">.ptr = ",
                          container.ptr);
        }

        inout this(inout ElementType[] array, in size_t[2] dim_) pure
        {
            container = ContainerType(array);
            dim = dim_;
            stride = calcStrides!storageOrder(dim);
            debug writeln("StorageDense2D<", &this, ">.this()",
                          " container<", &container, ">.ptr = ",
                          container.ptr);
        }

        inout this(inout ElementType[] array,
                   in size_t[2] dim_, in size_t[2] stride_) pure
        {
            container = ContainerType(array);
            dim = dim_;
            stride = stride_;
            debug writeln("StorageDense2D<", &this, ">.this()",
                          " container<", &container, ">.ptr = ",
                          container.ptr);
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
                debug writeln("StorageDense2D<", &this, ">._reallocate()");
                stride = calcStrides!storageOrder(dim);
                container = ContainerType(calcContainerSize(dim));
            }

            void setDimensions(in size_t[2] dim_) pure
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

    package // Copy-on-write support
    {
        private void _share() pure
        {
            debug(cow) writeln("StorageDense2D<", &this, ">._share()");
            static if(!isStatic)
            {
                container.addRef();
            }
        }

        private void _unshare() pure
        {
            debug(cow) writeln("StorageDense2D<", &this, ">._unshare()");
            static if(!isStatic)
            {
                if(!container.isShared)
                    return;
                container.remRef();
                auto oldContainer = container;
                auto oldStride = stride;
                _reallocate();
                copy2D(oldContainer.array, oldStride,
                       container.array, stride, dim);
            }
        }

        void onChange() pure
        {
            debug(cow) writeln("StorageDense2D<", &this, ">.onChange()");
            _unshare();
        }
    }

    public // Slices and indices support
    {
        package size_t mapIndex(size_t irow, size_t icol) pure const
        {
            return irow * stride[0] + icol * stride[1];
        }

        ref const(ElementType) readElement(size_t irow, size_t icol) pure const
        {
            return container[mapIndex(irow, icol)];
        }

        ref ElementType takeElement(size_t irow, size_t icol) pure
        {
            onChange();
            return container[mapIndex(irow, icol)];
        }

        const(StorageDense2D!(ElementType, storageOrder,
                              dynamicSize, dynamicSize))
            sliceCopy(SliceBounds row, SliceBounds col) pure const
        {
            debug writeln("StorageDense2D<", &this, ">.sliceCopy() const");
            return typeof(return)(
                container[mapIndex(row.lo, col.lo)
                          ..(mapIndex(row.up - 1, col.up - 1) + 1)],
                [row.up - row.lo, col.up - col.lo],
                stride);
        }

        StorageDense2D!(ElementType, storageOrder,
                        dynamicSize, dynamicSize)
            sliceCopy(SliceBounds row, SliceBounds col) pure
        {
            debug writeln("StorageDense2D<", &this, ">.sliceCopy()");
            _share();
            return typeof(return)(
                container[mapIndex(row.lo, col.lo)
                          ..(mapIndex(row.up - 1, col.up - 1) + 1)],
                [row.up - row.lo, col.up - col.lo],
                stride);
        }

        inout(ViewDense2D!(typeof(this)))
            sliceView(SliceBounds row, SliceBounds col) pure inout
        {
            debug writeln("StorageDense2D<", &this, ">.sliceView()");
            return typeof(return)(this,
                                  mapIndex(row.lo, col.lo),
                                  [row.up - row.lo, col.up - col.lo],
                                  [row.st, col.st]);
        }
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container.array, dim, stride);
    }
}

/* Dense multidimensional storage */
struct ViewDense2D(StorageType)
{
    public // Check and process parameters
    {
        enum size_t[] dimPattern = [dynamicSize, dynamicSize];

        alias StorageType.ElementType ElementType; // Type of the array elements
        public enum uint rank = 2; // Number of dimensions
        alias StorageType.storageOrder storageOrder;

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = false;

        alias StorageType.ContainerType ContainerType;
    }

    package // Container, dimensions, strides
    {
        StorageType* pStorage;

        const size_t offset;
        const size_t[2] dim;
        const size_t[2] stride;
    }

    // Copy-on-write support
    package void onChange() pure
    {
        debug(cow) writeln("ViewDense2D<", &this, ">.onChange()");
        pStorage.onChange();
    }

    public // Slices and indices support
    {
        package size_t mapIndex(size_t irow, size_t icol) pure const
        {
            return
                offset
                + irow * stride[0] * pStorage.stride[0]
                + icol * stride[1] * pStorage.stride[1];
        }

        ref const(ElementType) readElement(size_t irow, size_t icol) pure const
        {
            return pStorage.container[mapIndex(irow, icol)];
        }

        ref ElementType takeElement(size_t irow, size_t icol) pure
        {
            onChange();
            return pStorage.container[mapIndex(irow, icol)];
        }

        inout(StorageDense2D!(ElementType, storageOrder,
                              dynamicSize, dynamicSize))
            sliceCopy(SliceBounds row, SliceBounds col) pure inout
        {
            debug writeln("ViewDense2D<", &this, ">.sliceCopy()");
            return typeof(return)(
                pStorage.container[mapIndex(row.lo, col.lo)
                                   ..(mapIndex(row.up - 1, col.up - 1) + 1)],
                [row.up - row.lo, col.up - col.lo],
                [stride[0] * pStorage.stride[0],
                 stride[1] * pStorage.stride[1]]);
        }

        inout(ViewDense2D!(typeof(*pStorage)))
            sliceView(SliceBounds row, SliceBounds col) pure inout
        {
            debug writeln("ViewDense2D<", &this, ">.sliceView()");
            return typeof(return)(*pStorage,
                                  mapIndex(row.lo, col.lo),
                                  [row.up - row.lo, col.up - col.lo],
                                  [stride[0] * pStorage.stride[0],
                                   stride[1] * pStorage.stride[1]]);
        }
    }

    this(inout ref StorageType storage,
         size_t offset, in size_t[2] dim_, in size_t[2] stride_) pure inout
    {
        pStorage = &storage;
        offset = offset;
        dim = dim_;
        stride = stride_;
        debug writeln("ViewDense2D<", &this, ">.this()",
                      " storage<", pStorage, ">.container.ptr = ",
                      pStorage.container.ptr);
    }
}

template is2DStorage(T)
{
    enum bool is2DStorage = isInstanceOf!(StorageDense2D, T);
}

template is2DView(T)
{
    enum bool is2DView = isInstanceOf!(ViewDense2D, T);
}

template is2DStorageOrView(T)
{
    enum bool is2DStorageOrView = is2DStorage!T || is2DView!T;
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
    debug writeln("storage-unittest-begin");
    auto a = StorageDense2D!(int, StorageOrder.rowMajor,
                             dynamicSize, dynamicSize)(
                                 array(iota(24)), [4, 6]);
    a.onChange();
    assert(!a.container.isShared);
    auto b = a.sliceCopy(SliceBounds(1, 3), SliceBounds(2, 5));
    assert(a.container.isShared);
    assert(b.container.isShared);
    assert(b.container.ptr == a.container.ptr + a.mapIndex(1, 2));
    b.onChange();
    assert(!a.container.isShared);
    assert(!b.container.isShared);
    assert(!b.container.intersect(a.container));
    b = a.sliceCopy(SliceBounds(1, 3), SliceBounds(2, 5));
    auto c = a.sliceView(SliceBounds(1, 3), SliceBounds(2, 5));
    assert(a.container.isShared);
    assert(b.container.isShared);
    c.onChange();
    assert(!a.container.isShared);
    assert(!b.container.isShared);
    debug writeln("storage-unittest-end");
}

unittest
{
    debug writeln("storage-unittest-begin");
    auto a = StorageDense2D!(int, StorageOrder.rowMajor, 4, 6)(array(iota(24)));
    a.onChange();
    auto b = a.sliceCopy(SliceBounds(1, 3), SliceBounds(2, 5));
    assert(!b.container.isShared);
    b.onChange();
    assert(!b.container.isShared);
    debug writeln("storage-unittest-end");
}
