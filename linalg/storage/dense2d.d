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

    static if(isStatic)
    {
        //TODO
    }
    else
    {
        this(inout ContainerType container_,
             in size_t[2] dim_, in size_t[2] stride_) pure inout
        {
            container = container_;
            dim = dim_;
            stride = stride_;
        }
    }

    package // Copy-on-write support
    {
        private void _share() pure inout
        {
            static if(isMutable!(typeof(this)))
            {
                debug(cow) writeln("StorageDense2D._share()");
            }
            /* Nothing to do with constant storage */
        }

        private void _unshare() pure inout
        {
            static if(isMutable!(typeof(this)))
            {
                debug(cow) writeln("StorageDense2D._unshare()");
            }
            /* Nothing to do with constant storage */
        }

        void onChange() pure inout
        {
            debug(cow) writeln("StorageDense2D.onChange()");
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

        inout(StorageDense2D!(ElementType, storageOrder,
                              dynamicSize, dynamicSize))
            sliceCopy(SliceBounds row, SliceBounds col) pure inout
        {
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
            return typeof(return)(this,
                                  mapIndex(row.lo, col.lo),
                                  [row.up - row.lo, col.up - col.lo],
                                  stride);
        }
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container, dim, stride);
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
    package void onChange() pure inout
    {
        debug(cow) writeln("ViewDense2D.onChange()");
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
    }

    this(inout ref StorageType storage,
         size_t offset, in size_t[2] dim_, in size_t[2] stride_) pure inout
    {
        pStorage = &storage;
        offset = offset;
        dim = dim_;
        stride = stride_;
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
