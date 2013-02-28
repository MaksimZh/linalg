// Written in the D programming language.

module linalg.storage.densemd;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.types;
import linalg.storage.container;
import linalg.storage.mdarray;

// Calculates strides in data array for dense storage
size_t[] calcStrides(StorageOrder storageOrder)(in size_t[] dim) pure
{
    if(dim.length == 1)
        return [1];
    else
        static if(storageOrder == StorageOrder.rowMajor)
        {
            auto tail = calcStrides!storageOrder(dim[1..$]);
            return [dim[1] * tail[0]] ~ tail;
        }
        else static if(storageOrder == StorageOrder.colMajor)
        {
            auto tail = calcStrides!storageOrder(dim[0..$-1]);
            return tail ~ [dim[$-2] * tail[$-1]];
        }
        else static assert(false);
}

unittest
{
    assert(calcStrides!(StorageOrder.rowMajor)([2, 3, 4]) == [12, 4, 1]);
    static assert(calcStrides!(StorageOrder.rowMajor)([2, 3, 4]) == [12, 4, 1]);
    assert(calcStrides!(StorageOrder.colMajor)([2, 3, 4]) == [1, 2, 6]);
    static assert(calcStrides!(StorageOrder.colMajor)([2, 3, 4]) == [1, 2, 6]);
}

// Calculates container size for dense storage
size_t calcContainerSize(in size_t[] dim) pure
{
    //TODO: Clean this when std.algorithm functions become pure
    uint result = 1;
    foreach(d; dim)
        result *= d;
    return result;
}

// Convert storage to built-in multidimensional array
auto toArray(T, uint rank)(in T[] container,
                           in size_t[] dim,
                           in size_t[] stride)
    in
    {
        assert(dim.length == rank);
        assert(stride.length == rank);
    }
body
{
    static if(rank > 0)
    {
        auto result = new MultArrayType!(T, rank - 1)[dim[0]];
        foreach(i; 0..dim[0])
            result[i] =
                toArray!(T, rank - 1)(container[(stride[0] * i)..$],
                                      dim[1..$],
                                      stride[1..$]);
        return result;
    }
    else
        return container[0];
}

unittest // toArray
{
    assert(toArray!(int, 3)(array(iota(24)), [2, 3, 4], [12, 4, 1])
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
}

/* Dense multidimensional storage */
struct StorageDenseMD(T, StorageOrder storageOrder_, params...)
{
    public // Check and process parameters
    {
        static assert(params.length >= 1);

        enum size_t[] dimPattern = [params[0..$]];

        alias T ElementType; // Type of the array elements
        public enum uint rank = dimPattern.length; // Number of dimensions
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
            enum size_t[] dim = dimPattern;
            enum size_t[] stride = calcStrides!storageOrder(dim);
        }
        else
        {
            size_t[rank] dim = dimPattern;
            size_t[rank] stride;
        }
    }

    MultArrayType!(ElementType, rank) opCast()
    {
        return toArray!(ElementType, rank)(container, dim, stride);
    }
}

/* Dense multidimensional view storage */
struct StorageDenseMDView(T, StorageOrder storageOrder_, size_t rank_)
{
    public // Check and process parameters
    {
        static assert(rank_ >= 1);
        public enum uint rank = rank_; // Number of dimensions

        enum size_t[rank] dimPattern = dynamicSize;

        alias T ElementType; // Type of the array elements
        enum StorageOrder storageOrder = storageOrder_;

        /* View dimensions assumed never known at compile time */
        enum bool isStatic = false;

        alias DynamicArray!ElementType ContainerType;
    }

    package // Container, dimensions, strides
    {
        ContainerType container;

        size_t[rank] dim = dimPattern;
        size_t[rank] stride;
    }

    MultArrayType!(ElementType, rank) opCast()
    {
        return toArray!(ElementType, rank)(container, dim, stride);
    }
}
