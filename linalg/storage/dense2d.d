// Written in the D programming language.

module linalg.storage.dense2d;

import std.algorithm;

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

    private // Copy-on-write support
    {
        void _share() pure inout
        {
        }

        void _unshare() pure inout
        {
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
            _unshare();
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

        StorageDense2DView!(ElementType, storageOrder)
            sliceView(SliceBounds row, SliceBounds col) pure
        {
            _unshare();
            return typeof(return)(
                container[mapIndex(row.lo, col.lo)
                          ..(mapIndex(row.up - 1, col.up - 1) + 1)],
                [row.up - row.lo, col.up - col.lo],
                stride);
        }

        const(StorageDense2DView!(ElementType, storageOrder))
            sliceConstView(SliceBounds row, SliceBounds col) pure const
        {
            return typeof(return)(
                container[mapIndex(row.lo, col.lo)
                          ..(mapIndex(row.up - 1, col.up - 1) + 1)],
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
struct StorageDense2DView(T, StorageOrder storageOrder_)
{
    public // Check and process parameters
    {
        enum size_t[] dimPattern = [dynamicSize, dynamicSize];

        alias T ElementType; // Type of the array elements
        public enum uint rank = 2; // Number of dimensions
        enum StorageOrder storageOrder = storageOrder_;

        /* Whether this is a static array with fixed dimensions and strides */
        enum bool isStatic = false;

        alias DynamicArray!ElementType ContainerType;
    }

    package // Container, dimensions, strides
    {
        ContainerType container;

        size_t[2] dim;
        size_t[2] stride;
    }

    this(inout ContainerType container_,
         in size_t[2] dim_, in size_t[2] stride_) pure inout
    {
        container = container_;
        dim = dim_;
        stride = stride_;
    }

    ElementType[][] opCast() pure const
    {
        return toArray(container, dim, stride);
    }
}
