// Written in the D programming language.

/** Matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.matrix;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.base;
import linalg.aux;
import linalg.mdarray;
import linalg.stride;
import linalg.iteration;

/* Operations specific for arrays */
mixin template matrixOperations(FinalType,
                                StorageType storageType,
                                StorageOrder storageOrder)
{
    //XXX: DMD issue 9235: this method should be in linalg.base.basicOperations
    auto opCast(Tdest)()
        if(is(Tdest == MultArrayType!(ElementType, rank)))
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _data);
    }

    static if((dimPattern[0] == 1) || (dimPattern[1] == 1))
        auto opCast(Tdest)()
            if(is(Tdest == ElementType[]))
        {
            return array(byElement);
        }

    //XXX: DMD issue 9235: + and - should be in linalg.base.basicOperations
    FinalType opBinary(string op, Trhs)(Trhs rhs)
        if(((op == "-") || (op == "+"))
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

/* Slicing and indexing management for arrays and matrices */
mixin template matrixSliceProxy(SourceType, alias constructSlice)
{
    /* Auxiliary structure for slicing and indexing */
    struct SliceProxy(bool isRegular)
    {
        SliceBounds bounds;

        SourceType* source; // Pointer to the container being sliced

        package this(SourceType* source_, SliceBounds bounds_)
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
                return constructSlice!(true, true)(
                    source, bounds, SliceBounds(0, source._dim[1]));
            }

            auto opSlice(size_t lo, size_t up)
            {
                /* Slice is a matrix (rank = 2) */
                return constructSlice!(true, true)(
                    source, bounds, SliceBounds(lo, up));
            }

            auto opIndex(size_t i)
            {
                /* Slice is a vector (rank = 1) */
                return constructSlice!(true, false)(
                    source, bounds, SliceBounds(i));
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
                return constructSlice!(false, true)(
                    source, bounds, SliceBounds(0, source._dim[1]));
            }

            auto opSlice(size_t lo, size_t up)
            {
                /* Slice is a vector (rank = 1) */
                return constructSlice!(false, true)(
                    source, bounds, SliceBounds(lo, up));
            }

            ref auto opIndex(size_t i)
            {
                /* Access to an element by index */
                return source._data[source._stride[0] * bounds.lo
                                    + source._stride[1] * i];
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
        return typeof(return)(&this, SliceBounds(0, _dim[0]));
    }

    SliceProxy!(true) opSlice(size_t lo, size_t up)
    {
        return typeof(return)(&this, SliceBounds(lo, up));
    }

    SliceProxy!(false) opIndex(size_t i)
    {
        return typeof(return)(&this, SliceBounds(i));
    }
}

struct ByRow(T, StorageOrder storageOrder)
{
    //TODO: optimize
    private
    {
        const size_t[2] _dim;
        const size_t[2] _stride;
        T[] _data;

        T* _ptr;
        const size_t _len;
        const T* _ptrFinal;
    }

    this(in size_t[] dim, in size_t[] stride, T[] data)
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        _dim = dim;
        _stride = stride;
        _data = data;
        _ptr = _data.ptr;
        _len = (_dim[1] - 1) * _stride[1] + 1;
        _ptrFinal = _data.ptr + (_dim[0] - 1) * _stride[0];
    }

    @property bool empty() { return !(_ptr <= _ptrFinal); }
    @property auto front()
    {
        return MatrixView!(T, false, true, storageOrder)(
            _ptr[0.._len], _dim[1], _stride[1]);
    }
    void popFront()
    {
        _ptr += _stride[0];
    }
}

struct ByColumn(T, StorageOrder storageOrder)
{
    //TODO: optimize
    private
    {
        const size_t[2] _dim;
        const size_t[2] _stride;
        T[] _data;

        T* _ptr;
        const size_t _len;
        const T* _ptrFinal;
    }

    this(in size_t[] dim, in size_t[] stride, T[] data)
        in
        {
            assert(stride.length == dim.length);
        }
    body
    {
        _dim = dim;
        _stride = stride;
        _data = data;
        _ptr = _data.ptr;
        _len = (_dim[0] - 1) * _stride[0] + 1;
        _ptrFinal = _data.ptr + (_dim[1] - 1) * _stride[1];
    }

    @property bool empty() { return !(_ptr <= _ptrFinal); }
    @property auto front()
    {
        return MatrixView!(T, false, true, storageOrder)(
            _ptr[0.._len], _dim[0], _stride[0]);
    }
    void popFront()
    {
        _ptr += _stride[1];
    }
}

/** Matrix view
*/
struct MatrixView(T, bool multRow, bool multCol,
                  StorageOrder storageOrder_ = StorageOrder.rowRow)
{
    enum StorageOrder storageOrder = storageOrder_;
    enum size_t[] dimPattern = [multRow ? dynamicSize : 1,
                                multCol ? dynamicSize : 1];
    alias Matrix!(T, dimPattern[0], dimPattern[1], storageOrder_) MatrixType;

    mixin storage!(T, dimPattern, true, storageOrder);

    static if(multRow != multCol)
        package this()(T[] data, size_t dim, size_t stride)
        {
            _data = data;
            static if(multRow)
            {
                _dim = [dim, 1];
                _stride = [stride, 1];
            }
            else
            {
                _dim = [1, dim];
                _stride = [1, stride];
            }
        }

    package this(SourceType)(ref SourceType source,
                             SliceBounds boundsRow, SliceBounds boundsCol)
        if(isStorage!SourceType)
    {
        /* Lower boundary in the container */
        size_t bndLo =
            source._stride[0] * boundsRow.lo
            + source._stride[1] * boundsCol.lo;
        /* Upper boundary in the container */
        size_t bndUp =
            source._stride[0]
            * (multRow ? boundsRow.up - 1 : boundsRow.up)
            +
            source._stride[1]
            * (multCol ? boundsCol.up - 1 : boundsCol.up)
            + 1;

        _dim = [boundsRow.up - boundsRow.lo + (multRow ? 0 : 1),
                boundsCol.up - boundsCol.lo + (multCol ? 0 : 1)];
        _stride = source._stride;
        _data = source._data[bndLo..bndUp];
    }

    mixin basicOperations!(MatrixType, storageType, storageOrder);

    auto byRow()
    {
        return ByRow!(T, storageOrder)(_dim, _stride, _data);
    }

    auto byColumn()
    {
        return ByColumn!(T, storageOrder)(_dim, _stride, _data);
    }

    mixin matrixOperations!(MatrixType, storageType, storageOrder);
}

/** Matrix
*/
struct Matrix(T, size_t nrows, size_t ncols,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    enum StorageOrder storageOrder = storageOrder_;
    enum size_t[] dimPattern = [nrows, ncols];

    mixin storage!(T, dimPattern, true, storageOrder);

    static if(storageType == StorageType.fixed)
        // Convert ordinary 1D array to static MD array with dense storage
        this(T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _data = source;
        }
    else
        /* Convert ordinary 1D array to dense multidimensional array
           with given dimensions
         */
        this(T[] source, size_t nrows, size_t ncols)
            in
            {
                assert(isCompatibleDimensions([nrows, ncols]));
            }
        body
        {
            _data = source;
            _dim = [nrows, ncols];
            _stride = calcDenseStrides(
                _dim, storageOrder == StorageOrder.columnMajor);
        }

    /* Slicing and indexing */
    auto constructSlice(bool isRegRow, bool isRegCol)(
        Matrix* source, SliceBounds boundsRow, SliceBounds boundsCol)
    {
        return MatrixView!(T, isRegRow, isRegCol, storageOrder)(
            *source, boundsRow, boundsCol);
    }

    mixin matrixSliceProxy!(Matrix, Matrix.constructSlice);

    mixin basicOperations!(Matrix, storageType, storageOrder);

    auto byRow()
    {
        return ByRow!(T, storageOrder)(_dim, _stride, _data);
    }

    auto byColumn()
    {
        return ByColumn!(T, storageOrder)(_dim, _stride, _data);
    }

    mixin matrixOperations!(Matrix, storageType, storageOrder);
}

unittest // Type properties and dimensions
{
    {
        alias Matrix!(double, dynamicSize, dynamicSize) A;
        static assert(is(A.ElementType == double));
        static assert(A.storageType == StorageType.resizeable);
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
