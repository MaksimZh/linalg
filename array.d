// Written in the D programming language.

/** Multidimensional arrays.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.array;

import std.algorithm;

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
import linalg.iteration;

version(none)
{
/* Operations specific for arrays */
mixin template arrayOperations(FinalType,
                               StorageType storageType,
                               StorageOrder storageOrder)
{
    //XXX: DMD issue 9235: this method should be in linalg.base.basicOperations
    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _data);
    }

    //XXX: DMD issue 9235: + and - should be in linalg.base.basicOperations
    FinalType opBinary(string op, Trhs)(Trhs rhs)
        if(((op == "-") || (op == "+") || (op == "*") || (op == "/"))
           && isStorage!Trhs
           && (is(typeof(mixin("this.byElement().front"
                               ~ op ~ "rhs.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        linalg.iteration.applyBinary!op(this.byElement(),
                                        rhs.byElement(),
                                        result.byElement());
        return result;
    }
}
}

/** Array view.
    Currently used only to slice compact multidimensional array.
    Unlike arrays views do not perform memory management.
*/
struct ArrayView(T, uint rank_,
                 StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    alias Storage!(T, repeatTuple!(rank_, dynamicSize), true, storageOrder_)
        StorageType;
    alias Array!(T, repeatTuple!(rank_, dynamicSize), storageOrder_) ArrayType;

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
    }

    this(T[] data, size_t[rank] dim, size_t[rank] stride)
    {
        storage = StorageType(data, dim, stride);
    }

    version(none)
    {
    /* Make slice of an array or slice */
    package this(SourceType)(ref SourceType source, SliceBounds[] bounds)
        if(isStorage!SourceType)
            in
            {
                assert(bounds.length == source.rank);
                assert(count!("a.isRegularSlice")(bounds) == rank);
            }
    body
    {
        size_t bndLo = 0; // Lower boundary in the container
        size_t bndUp = 0; // Upper boundary in the container

        /* Dimensions and strides should be copied for all regular slices
           and omitted for indices.
           Boundaries should not cover additional elements.
        */
        uint idest = 0;
        foreach(i, b; bounds)
        {
            bndLo += source._stride[i] * b.lo;
            if(b.isRegularSlice)
            {
                bndUp += source._stride[i] * (b.up - 1);
                _dim[idest] = b.up - b.lo;
                _stride[idest] = source._stride[i];
                ++idest;
            }
            else
                bndUp += source._stride[i] * b.up;
        }
        ++bndUp;

        _data = source._data[bndLo..bndUp];
    }
    }
}

/** Multidimensional compact array */
struct Array(T, params...)
{
    public // Check and process parameters
    {
        /* Check the transposition flag (false by default). */
        static if(isValueOfTypeStrict!(StorageOrder, params[$-1]))
            alias Storage!(T, params[0..($-1)], false, params[$-1])
                StorageType;
        else
            alias Storage!(T, params, false, StorageOrder.rowMajor)
                StorageType;
    }

    StorageType storage; // Storage of the array data
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
    }

    /* Constructor taking built-in array as parameter */
    static if(isStatic) //XXX: why have to put "this."?
    {
        this(in T[] source)
        {
            storage = StorageType(source);
        }
    }
    else
    {
        this(T[] source, in size_t[] dim)
        {
            storage = StorageType(source, dim);
        }
    }
}

unittest // Type properties and dimensions
{
    {
        alias ArrayView!(int, 3) A;
        static assert(is(A.ElementType == int));
        static assert(!(A.isStatic));
        static assert(!(A.isResizeable));
        static assert(A.storageOrder == StorageOrder.rowMajor);
    }
    {
        alias Array!(int, dynamicSize, dynamicSize, dynamicSize) A;
        static assert(is(A.ElementType == int));
        static assert(!(A.isStatic));
        static assert(A.isResizeable);
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(24)), [2, 3, 4]);
        assert(a.length == 2);
        assert(a.dimensions == [2, 3, 4]);
    }
    {
        alias Array!(int, 2, 3, 4) A;
        static assert(is(A.ElementType == int));
        static assert(A.isStatic);
        static assert(!(A.isResizeable));
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(24)));
        assert(a.length == 2);
        assert(a.dimensions == [2, 3, 4]);
    }
}

version(none)
{
unittest // Slicing
{
    auto a = Array!(int, 2, 3, 4)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[1, 5, 9],
               [13, 17, 21]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[1, 2],
                [5, 6],
                [9, 10]],
               [[13, 14],
                [17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[][1][]
           == [[4, 5, 6, 7],
               [16, 17, 18, 19]]);
    assert(cast(int[]) a[][1][1]
           == [5, 17]);
    assert(cast(int[][]) a[][1][1..3]
           == [[5, 6],
               [17, 18]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[5, 9],
               [17, 21]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[5, 6],
                [9, 10]],
               [[17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[1][][]
           == [[12, 13, 14, 15],
               [16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][][1]
           == [13, 17, 21]);
    assert(cast(int[][]) a[1][][1..3]
           == [[13, 14],
               [17, 18],
               [21, 22]]);
    assert(cast(int[]) a[1][1][]
           == [16, 17, 18, 19]);
    assert(a[1][1][1] == 17);
    assert(cast(int[]) a[1][1][1..3]
           == [17, 18]);
    assert(cast(int[][]) a[1][1..3][]
           == [[16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [17, 21]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[17, 18],
               [21, 22]]);
}

unittest // Slicing, transposed
{
    auto a = Array!(int, 2, 3, 4, StorageOrder.columnMajor)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 6, 12, 18],
                [2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[1, 7, 13, 19],
                [3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[6, 8, 10],
               [7, 9, 11]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[6, 12],
                [8, 14],
                [10, 16]],
               [[7, 13],
                [9, 15],
                [11, 17]]]);

    assert(cast(int[][]) a[][1][]
           == [[2, 8, 14, 20],
               [3, 9, 15, 21]]);
    assert(cast(int[]) a[][1][1]
           == [8, 9]);
    assert(cast(int[][]) a[][1][1..3]
           == [[8, 14],
               [9, 15]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[8, 10],
               [9, 11]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[8, 14],
                [10, 16]],
               [[9, 15],
                [11, 17]]]);
    assert(cast(int[][]) a[1][][]
           == [[1, 7, 13, 19],
               [3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][][1]
           == [7, 9, 11]);
    assert(cast(int[][]) a[1][][1..3]
           == [[7, 13],
               [9, 15],
               [11, 17]]);
    assert(cast(int[]) a[1][1][]
           == [3, 9, 15, 21]);
    assert(a[1][1][1]
           == 9);
    assert(cast(int[]) a[1][1][1..3]
           == [9, 15]);
    assert(cast(int[][]) a[1][1..3][]
           == [[3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [9, 11]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[9, 15],
               [11, 17]]);
}
}

version(none)
{
unittest // Iterators
{
    // Normal
    {
        auto a = Array!(int, 2, 3, 4)(array(iota(24)));
        int[] test = array(iota(24));
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }

    // Transposed
    {
        auto a = Array!(int, 2, 3, 4,
                        StorageOrder.columnMajor)(array(iota(0, 24)));
        int[] test = [0, 6, 12, 18,
                      2, 8, 14, 20,
                      4, 10, 16, 22,

                      1, 7, 13, 19,
                      3, 9, 15, 21,
                      5, 11, 17, 23];
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Iterators for slice
{
    {
        auto a = Array!(int, 2, 3, 4)(array(iota(24)));
        int[] test = [5, 6,
                      9, 10,

                      17, 18,
                      21, 22];
        int[] result = [];
        foreach(v; a[][1..3][1..3].byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Assignment
{
    alias Array!(int, 2, 3, 4) A;
    A a, b;
    a = A(array(iota(0, 24)));
    auto test = [[[0, 1, 2, 3],
                  [4, 5, 6, 7],
                  [8, 9, 10, 11]],
                 [[12, 13, 14, 15],
                  [16, 17, 18, 19],
                  [20, 21, 22, 23]]];
    assert(cast(int[][][])(b = a) == test);
    assert(cast(int[][][])b == test);
    alias Array!(int, 0, 3, 0) A1;
    A1 a1, b1;
    a1 = A1(array(iota(0, 24)), [2, 3, 4]);
    assert(cast(int[][][])(b1 = a1) == test);
    assert(cast(int[][][])b1 == test);
}

unittest // Assignment for slices
{
    auto a = Array!(int, 2, 3, 4)(array(iota(0, 24)));
    auto b = Array!(int, 2, 2, 2)(array(iota(24, 32)));
    auto c = a[][1..3][1..3];
    auto test = [[[0, 1, 2, 3],
                  [4, 24, 25, 7],
                  [8, 26, 27, 11]],
                 [[12, 13, 14, 15],
                  [16, 28, 29, 19],
                  [20, 30, 31, 23]]];
    assert(cast(int[][][]) (c = b) == cast(int[][][]) b);
    assert(cast(int[][][]) a == test);
    a[1][1][1] = 100;
    assert(a[1][1][1] == 100);
}

unittest // Comparison
{
    auto a = Array!(int, 2, 3, 4)(array(iota(24)));
    auto b = Array!(int, dynamicSize, dynamicSize, dynamicSize)(array(iota(24)),
                                                                [2, 3, 4]);
    assert(a == b);
    assert(b == a);
    assert(a[][1..3][2] == b[][1..3][2]);
    assert(a[][1..3][2] != b[][1..3][3]);
}

unittest // Unary operations
{
    auto a = Array!(int, 2, 3, 4)(array(iota(24)));
    assert(cast(int[][][]) (+a)
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][][]) (-a)
           == [[[-0, -1, -2, -3],
                [-4, -5, -6, -7],
                [-8, -9, -10, -11]],
               [[-12, -13, -14, -15],
                [-16, -17, -18, -19],
                [-20, -21, -22, -23]]]);
    assert(cast(int[][][]) (-a[][1..3][1..3])
           == [[[-5, -6],
                [-9, -10]],
               [[-17, -18],
                [-21, -22]]]);
}

unittest // Binary operations
{
    alias Array!(int, 2, 3, 4) A;
    auto a1 = A(array(iota(24)));
    auto a2 = A(array(iota(24, 48)));
    assert(a1 + a2 == A(array(iota(24, 24 + 48, 2))));
    assert(cast(int[][]) (a1[1][1..3][1..3] + a2[0][1..3][1..3])
           == [[17 + 29, 18 + 30],
               [21 + 33, 22 + 34]]);
     assert(cast(int[][]) (a1[1][1..3][1..3] * a2[0][1..3][1..3])
           == [[17 * 29, 18 * 30],
               [21 * 33, 22 * 34]]);
}
}