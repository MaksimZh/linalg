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
        enum bool isResizeable = !isStatic;

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
            container = ContainerType(array);
            debug(storage) writeln("StorageDense2D<", &this, ">.this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }
    }
    else
    {
        this()(in size_t[2] dim)
        {
            container = ContainerType(calcContainerSize(dim));
            this.dim = dim;
            stride = calcStrides!storageOrder(dim);
            debug(storage) writeln("StorageDense2D<", &this, ">.this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }

        inout this()(inout ContainerType container,
                   in size_t[2] dim, in size_t[2] stride) pure
        {
            this.container = container;
            this.dim = dim;
            this.stride = stride;
            debug(storage) writeln("StorageDense2D<", &this, ">.this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }

        inout this()(inout ElementType[] array, in size_t[2] dim) pure
        {
            container = ContainerType(array);
            this.dim = dim;
            stride = calcStrides!storageOrder(dim);
            debug(storage) writeln("StorageDense2D<", &this, ">.this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }

        inout this()(inout ElementType[] array,
                     in size_t[2] dim, in size_t[2] stride) pure
        {
            container = ContainerType(array);
            this.dim = dim;
            this.stride = stride;
            debug(storage) writeln("StorageDense2D<", &this, ">.this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }

        pure ~this()
        {
            debug(storage) writeln("StorageDense2D<", &this, ">.~this()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
            _release();
        }
    }

    public // Copying
    {
        inout this(this) pure
        {
            onShare();
            debug(storage) writeln("StorageDense2D<", &this, ">.this(this)",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
        }

        ref StorageDense2D opAssign(Tsource)(ref Tsource source) pure
            if(is2DStorageOrView!Tsource)
        {
            onReset();
            source.onShare();
            container = source.container;
            static if(!isStatic)
            {
                dim = source.dim;
                stride = source.stride;
            }
            debug(storage) writeln("StorageDense2D<", &this, ">.opAssign()",
                                   " container<", &(this.container), ">.ptr = ",
                                   this.container.ptr);
            return this;
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
                debug(storage) writeln("StorageDense2D<", &this,
                                       ">._reallocate()");
                stride = calcStrides!storageOrder(dim);
                container = ContainerType(calcContainerSize(dim));
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

    public // Copy-on-write support
    {
        private void _share() pure const
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

        private void _release() pure const
        {
            debug(cow) writeln("StorageDense2D<", &this, ">._release()");
            static if(!isStatic)
            {
                if(!container.isInitialized)
                    return;
                if(!container.isShared)
                    return;
                container.remRef();
            }
        }

        /* Call this method before changing data */
        void onChange() pure
        {
            debug(cow) writeln("StorageDense2D<", &this, ">.onChange()");
            _unshare();
        }

        /* Call this method before sharing data */
        void onShare() pure const
        {
            debug(cow) writeln("StorageDense2D<", &this, ">.onShare()");
            _share();
        }

        /* Call this method before data reallocation */
        void onReset() pure
        {
            debug(cow) writeln("StorageDense2D<", &this, ">.onReset()");
            _release();
            static if(!isStatic)
            {
                container = typeof(container).init;
            }
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

        inout(ViewDense2D!(typeof(this)))
            slice(SliceBounds row, SliceBounds col) pure inout
        {
            debug(slice) writeln("StorageDense2D<", &this, ">.sliceView(",
                                 row, ", ", col, ")");
            return typeof(return)(this,
                                  [row.lo, col.lo],
                                  [row.up - row.lo, col.up - col.lo],
                                  [row.st || 1, col.st || 1]);
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
        enum bool isResizeable = false;

        alias DynamicArray!ElementType ContainerType;
    }

    package // Container, dimensions, strides
    {
        StorageType* pStorage;
        const size_t[2] offset;
        const size_t[2] viewStride;

        @property inout(ContainerType) container() pure inout
        {
            size_t start = offset[0] * stride[0] + offset[1] * stride[1];
            size_t finish =
                start
                + (dim[0] - 1) * stride[0]
                + (dim[1] - 1) * stride[1]
                + 1;
            return pStorage.container[start..finish];
        }
        const size_t[2] dim;
        @property const size_t[2] stride() pure const
        {
            return [pStorage.stride[0] * viewStride[0],
                    pStorage.stride[1] * viewStride[1]];
        }
    }

    /* Constructor */
    inout this(ref inout StorageType storage,
               in size_t[2] offset,
               in size_t[2] dim,
               in size_t[2] stride) pure
    {
        pStorage = &storage;
        this.offset = offset;
        this.dim = dim;
        viewStride = stride;
        debug(slice) writeln("ViewDense2D<", &this, ">.this(",
                             offset, ", ", dim, ", ", stride, ")",
                             " storage<", pStorage, ">.container.ptr = ",
                             pStorage.container.ptr);
    }

    public // Dimensions and memory
    {
        @property size_t nrows() pure const { return dim[0]; }
        @property size_t ncols() pure const { return dim[1]; }

        /* Test dimensions for compatibility */
        bool isCompatDim(in size_t[] dim_) pure
        {
            return dim == dim_;
        }
    }

    public // Copy-on-write support
    {
        /* Call this method before changing data */
        package void onChange() pure
        {
            debug(cow) writeln("ViewDense2D<", &this, ">.onChange()");
            pStorage.onChange();
        }

        /* Call this method before sharing data */
        package void onShare() pure
        {
            debug(cow) writeln("ViewDense2D<", &this, ">.onShare()");
            pStorage.onShare();
        }
    }

    public // Slices and indices support
    {
        package size_t mapIndex(size_t irow, size_t icol) pure const
        {
            return irow * viewStride[0] + icol * viewStride[1];
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

        inout(ViewDense2D!(typeof(*pStorage)))
            slice(SliceBounds row, SliceBounds col) pure inout
        {
            debug(slice) writeln("ViewDense2D<", &this, ">.sliceView()");
            return typeof(return)(*pStorage,
                                  [row.lo, col.lo],
                                  [row.up - row.lo, col.up - col.lo],
                                  stride);
        }
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container.array, dim, stride);
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
    debug(copy)
    {
        writeln("  copy from <", source.ptr, ">");
        writeln("  ", source, ", ", sStride, ", ", dim);
        writeln("  copy to <", dest.ptr, ">");
        writeln("  ", dest, ", ", dStride, ", ", dim);
    }
    auto isource = ByElement!(T, false)(source, dim, sStride);
    auto idest = ByElement!(T, true)(dest, dim, dStride);
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
    debug(copy)
    {
        writeln("  copy result");
        writeln("  ", dest);
    }
}

unittest
{
    debug(storage) writeln("storage-unittest-begin");
    debug(storage) writeln("a");
    auto a = StorageDense2D!(int, StorageOrder.rowMajor,
                             dynamicSize, dynamicSize)(
                                 array(iota(24)), [4, 6]);
    assert(!a.container.isShared);
    debug(storage) writeln("a.onChange");
    a.onChange();
    assert(!a.container.isShared);
    debug(storage) writeln("b = a");
    auto b = a;
    assert(a.container.isShared);
    assert(b.container.isShared);
    assert(b.container.intersect(a.container));
    debug(storage) writeln("b.onChange");
    b.onChange();
    assert(!a.container.isShared);
    assert(!b.container.isShared);
    assert(!b.container.intersect(a.container));
    debug(storage) writeln("b = a");
    b = a;
    assert(a.container.isShared);
    assert(b.container.isShared);
    assert(b.container.intersect(a.container));
    debug(storage) writeln("a.onChange");
    a.onChange();
    assert(!a.container.isShared);
    assert(!b.container.isShared);
    assert(!b.container.intersect(a.container));
    debug(storage) writeln("storage-unittest-end");
}

unittest
{
    debug(storage) writeln("storage-unittest-begin");
    alias
        StorageDense2D!(int, StorageOrder.rowMajor,
                        dynamicSize, dynamicSize)
        S;
    debug(storage) writeln("a");
    auto a = S(array(iota(24)), [4, 6]);
    assert(!a.container.isShared);
    debug(storage) writeln("b = a");
    const(S) b = a;
    assert(a.container.isShared);
    assert(b.container.isShared);
    assert(b.container.intersect(a.container));
    if(true)
    {
        debug(storage) writeln("c = b");
        const(S) c = b;
        assert(a.container.isShared);
        assert(b.container.isShared);
        assert(c.container.isShared);
        assert(b.container.intersect(a.container));
        assert(c.container.intersect(a.container));
        assert(c.container.intersect(b.container));
        debug(storage) writeln("a.onChange");
        a.onChange();
        assert(!a.container.isShared);
        assert(b.container.isShared);
        assert(c.container.isShared);
        assert(!b.container.intersect(a.container));
        assert(!c.container.intersect(a.container));
        assert(c.container.intersect(b.container));
    }
    assert(!b.container.isShared);
    debug(storage) writeln("storage-unittest-end");
}
