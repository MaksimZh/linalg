// Written in the D programming language.

/** Matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.matrix;

import std.algorithm;
import std.traits;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.storage;
import linalg.aux;
import linalg.mdarray;
import linalg.stride;

/** Matrix view
*/
struct MatrixView(T, bool multRow, bool multCol,
                  StorageOrder storageOrder_ = StorageOrder.rowRow)
{
    alias Storage!(T,
                   multRow ? dynamicSize : 1,
                   multCol ? dynamicSize : 1,
                   true, storageOrder_)
        StorageType;
    alias Matrix!(T,
                  multRow ? dynamicSize : 1,
                  multCol ? dynamicSize : 1,
                  storageOrder_)
        MatrixType;

    StorageType storage;
    public //XXX: "alias storage this"
    {
        version(none) alias storage this; //XXX: too buggy feature
        alias storage.dimPattern dimPattern;
        alias storage.ElementType ElementType;
        alias storage.rank rank;
        alias storage.storageOrder storageOrder;
        alias storage.isStatic isStatic;
        alias storage.isResizeable isResizeable;
        @property size_t length() pure const {
            return storage.length; }
        @property size_t[rank] dimensions() pure const {
            return storage.dimensions; }
        auto opCast(Tresult)() { return cast(Tresult)(storage); }
    }

    /* Constructor creating slice */
    package this(SourceType)(ref SourceType source,
                             SliceBounds boundsRow,
                             SliceBounds boundsCol)
        if(isStorage!(typeof(source.storage)))
    {
        storage = StorageType(source.storage, [boundsRow, boundsCol]);
    }
}

/** Matrix
*/
struct Matrix(T, size_t nrows, size_t ncols,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    alias Storage!(T, nrows, ncols, false, storageOrder_)
        StorageType;

    StorageType storage;
    public //XXX: "alias storage this"
    {
        version(none) alias storage this; //XXX: too buggy feature
        alias storage.dimPattern dimPattern;
        alias storage.ElementType ElementType;
        alias storage.rank rank;
        alias storage.storageOrder storageOrder;
        alias storage.isStatic isStatic;
        alias storage.isResizeable isResizeable;
        @property size_t length() pure const {
            return storage.length; }
        @property size_t[rank] dimensions() pure const {
            return storage.dimensions; }
        auto opCast(Tresult)() { return cast(Tresult)(storage); }
    }

    /* Constructor taking built-in array as parameter */
    static if(isStatic)
    {
        this(in T[] source)
        {
            storage = StorageType(source);
        }
    }
    else
    {
        this(T[] source, size_t nrows, size_t ncols)
        {
            storage = StorageType(source, [nrows, ncols]);
        }
    }

    public // Slicing and indexing
    {
        auto constructSlice(bool isRegRow, bool isRegCol)(
            SliceBounds boundsRow, SliceBounds boundsCol)
        {
            return MatrixView!(T, isRegRow, isRegCol, storageOrder)(
                this, boundsRow, boundsCol);
        }

        /* Auxiliary structure for slicing and indexing */
        struct SliceProxy(bool isRegular)
        {
            SliceBounds bounds;

            Matrix* source; // Pointer to the container being sliced

            package this(Matrix* source_, SliceBounds bounds_)
            {
                source = source_;
                bounds = bounds_;
            }

            /* Evaluate slicing result.
               Calling this method means that bracket set is incomplete.
               Just adds empty pair: []
            */
            auto eval()
            {
                return this[];
            }

            /* Slicing and indexing */
            static if(isRegular)
            {
                /* Slice of regular (multirow) slice can be a matrix
                   and can't be access to element by index
                */

                auto opSlice()
                {
                    /* Slice is a matrix (rank = 2) */
                    return source.constructSlice!(true, true)(
                        bounds, SliceBounds(0, source.dimensions[1]));
                }

                auto opSlice(size_t lo, size_t up)
                {
                    /* Slice is a matrix (rank = 2) */
                    return source.constructSlice!(true, true)(
                        bounds, SliceBounds(lo, up));
                }

                auto opIndex(size_t i)
                {
                    /* Slice is a vector (rank = 1) */
                    return source.constructSlice!(true, false)(
                        bounds, SliceBounds(i, i+1));
                }
            }
            else
            {
                /* Slice of one row (multirow) can be a vector
                   or access to element by index
                */

                auto opSlice()
                {
                    /* Slice is a vector (rank = 1) */
                    return source.constructSlice!(false, true)(
                        bounds, SliceBounds(0, source.dimensions[1]));
                }

                auto opSlice(size_t lo, size_t up)
                {
                    /* Slice is a vector (rank = 1) */
                    return source.constructSlice!(false, true)(
                        bounds, SliceBounds(lo, up));
                }

                ref auto opIndex(size_t i)
                {
                    /* Access to an element by index */
                    return source.storage.accessByIndex(
                        [SliceBounds(bounds.lo), SliceBounds(i)]); //XXX
                }
            }

            auto opCast(Tresult)()
            {
                return cast(Tresult)(eval());
            }
        }

        /* Slicing and indexing */
        SliceProxy!(true) opSlice()
        {
            return typeof(return)(&this, SliceBounds(0, length));
        }

        SliceProxy!(true) opSlice(size_t lo, size_t up)
        {
            return typeof(return)(&this, SliceBounds(lo, up));
        }

        SliceProxy!(false) opIndex(size_t i)
        {
            return typeof(return)(&this, SliceBounds(i, i+1));
        }
    }

    version(none)
    {

    auto byRow()
    {
        return ByRow!(T, storageOrder)(_dim, _stride, _data);
    }

    auto byColumn()
    {
        return ByColumn!(T, storageOrder)(_dim, _stride, _data);
    }
    }
}

unittest // Type properties and dimensions
{
    {
        alias Matrix!(double, dynamicSize, dynamicSize) A;
        static assert(is(A.ElementType == double));
        static assert(!(A.isStatic));
        static assert(A.isResizeable);
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(12.0)), 3, 4);
        assert(a.dimensions == [3, 4]);
    }
}

unittest // Slicing
{
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    assert(cast(int[][]) a[][]
           == [[0, 1, 2, 3],
               [4, 5, 6, 7],
               [8, 9, 10, 11]]);
    assert(cast(int[][]) a[][1]
           == [[1],
               [5],
               [9]]);
    assert(cast(int[][]) a[][1..3]
           == [[1, 2],
               [5, 6],
               [9, 10]]);
    assert(cast(int[][]) a[1][]
           == [[4, 5, 6, 7]]);
    assert(a[1][1] == 5);
    assert(cast(int[][]) a[1..3][]
           == [[4, 5, 6, 7],
               [8, 9, 10, 11]]);
    assert(cast(int[][]) a[1..3][1]
           == [[5],
               [9]]);
    assert(cast(int[][]) a[1..3][1..3]
           == [[5, 6],
               [9, 10]]);
}

unittest // Slicing, transposed
{
    auto a = Matrix!(int, 3, 4, StorageOrder.columnMajor)(array(iota(12)));
    assert(cast(int[][]) a[][]
           == [[0, 3, 6, 9],
               [1, 4, 7, 10],
               [2, 5, 8, 11]]);
    assert(cast(int[][]) a[][1]
           == [[3],
               [4],
               [5]]);
    assert(cast(int[][]) a[][1..3]
           == [[3, 6],
               [4, 7],
               [5, 8]]);
    assert(cast(int[][]) a[1][]
           == [[1, 4, 7, 10]]);
    assert(a[1][1] == 4);
    assert(cast(int[][]) a[1..3][]
           == [[1, 4, 7, 10],
               [2, 5, 8, 11]]);
    assert(cast(int[][]) a[1..3][1]
           == [[4],
               [5]]);
    assert(cast(int[][]) a[1..3][1..3]
           == [[4, 7],
               [5, 8]]);
}

version(none)
{
unittest // Iterators
{
    // Normal
    {
        auto a = Matrix!(int, 3, 4)(array(iota(12)));
        int[][] result = [];
        foreach(v; a.byRow)
            result ~= [cast(int[]) v];
        assert(result == [[0, 1, 2, 3],
                          [4, 5, 6, 7],
                          [8, 9, 10, 11]]);
        result = [];
        foreach(v; a.byColumn)
            result ~= [cast(int[]) v];
        assert(result == [[0, 4, 8],
                          [1, 5, 9],
                          [2, 6, 10],
                          [3, 7, 11]]);
    }

    // Transposed
    {
        auto a = Matrix!(int, 3, 4, StorageOrder.columnMajor)(array(iota(12)));
        int[][] result = [];
        foreach(v; a.byRow)
            result ~= [cast(int[]) v];
        assert(result == [[0, 3, 6, 9],
                          [1, 4, 7, 10],
                          [2, 5, 8, 11]]);
        result = [];
        foreach(v; a.byColumn)
            result ~= [cast(int[]) v];
        assert(result == [[0, 1, 2],
                          [3, 4, 5],
                          [6, 7, 8],
                          [9, 10, 11]]);
    }
}

unittest // Iterators
{
    // Normal
    {
        auto a = Matrix!(int, 3, 4)(array(iota(12)));
        int[][] result = [];
        foreach(v; a[1..3][1..3].byRow)
            result ~= [cast(int[]) v];
        assert(result == [[5, 6],
                          [9, 10]]);
        result = [];
        foreach(v; a[1..3][1..3].byColumn)
            result ~= [cast(int[]) v];
        assert(result == [[5, 9],
                          [6, 10]]);
    }

    // Transposed
    {
        auto a = Matrix!(int, 3, 4, StorageOrder.columnMajor)(array(iota(12)));
        int[][] result = [];
        foreach(v; a[1..3][1..3].byRow)
            result ~= [cast(int[]) v];
        assert(result == [[4, 7],
                          [5, 8]]);
        result = [];
        foreach(v; a[1..3][1..3].byColumn)
            result ~= [cast(int[]) v];
        assert(result == [[4, 5],
                          [7, 8]]);
    }
}

unittest // Assignment
{
    alias Matrix!(int, 3, 4) A;
    A a, b;
    a = A(array(iota(12)));
    auto test = [[0, 1, 2, 3],
                 [4, 5, 6, 7],
                 [8, 9, 10, 11]];
    assert(cast(int[][])(b = a) == test);
    assert(cast(int[][])b == test);
    alias Matrix!(int, dynamicSize, dynamicSize) A1;
    A1 a1, b1;
    a1 = A1(array(iota(12)), 3, 4);
    assert(cast(int[][])(b1 = a1) == test);
    assert(cast(int[][])b1 == test);
}

unittest // Assignment for slices
{
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    auto b = Matrix!(int, 2, 2)(array(iota(12, 16)));
    auto c = a[1..3][1..3];
    auto test = [[0, 1, 2, 3],
                 [4, 12, 13, 7],
                 [8, 14, 15, 11]];
    assert(cast(int[][]) (c = b) == cast(int[][]) b);
    assert(cast(int[][]) a == test);
    a[1][1] = 100;
    assert(a[1][1] == 100);
}

unittest // Comparison
{
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    auto b = Matrix!(int, dynamicSize, dynamicSize)(array(iota(12)), 3, 4);
    assert(a == b);
    assert(b == a);
    assert(a[1..3][2] == b[1..3][2]);
    assert(a[1..3][2] != b[1..3][3]);
}

unittest // Unary operations
{
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    assert(cast(int[][]) (+a)
           == [[0, 1, 2, 3],
               [4, 5, 6, 7],
               [8, 9, 10, 11]]);
    assert(cast(int[][]) (-a)
           == [[-0, -1, -2, -3],
               [-4, -5, -6, -7],
               [-8, -9, -10, -11]]);
    assert(cast(int[][]) (-a[1..3][1..3])
           == [[-5, -6],
               [-9, -10]]);
}

unittest // Binary operations
{
    alias Matrix!(int, 3, 4) A;
    auto a1 = A(array(iota(12)));
    auto a2 = A(array(iota(12, 24)));
    assert(a1 + a2 == A(array(iota(12, 12 + 24, 2))));
    assert(cast(int[][]) (a1[0..2][1..3] + a2[1..3][1..3])
           == [[1 + 17, 2 + 18],
               [5 + 21, 6 + 22]]);
}
}
