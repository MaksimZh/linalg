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
    import std.complex;
}

import linalg.storage;
import linalg.aux;
import linalg.mdarray;
import linalg.stride;
import linalg.operations;
import linalg.iterators;

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
        auto byElement() { return storage.byElement(); }
    }

    enum size_t nrowsP = StorageType.dimPattern[0];
    enum size_t ncolsP = StorageType.dimPattern[1];

    enum bool isVector = (multRow != multCol);

    /* Constructor creating slice */
    package this(SourceType)(ref SourceType source,
                             SliceBounds boundsRow,
                             SliceBounds boundsCol)
        if(isStorage!(typeof(source.storage)))
    {
        storage = StorageType(source.storage, [boundsRow, boundsCol]);
    }

    this()(T[] data, size_t[rank] dim, size_t[rank] stride)
    {
        storage = StorageType(data, dim, stride);
    }

    /* Constructor converting 1D array to vector */
    static if(isVector)
        package this()(T[] data, size_t dim, size_t stride)
        {
            storage._data = data;
            static if(multRow)
            {
                storage._dim = [dim, 1];
                storage._stride = [stride, 1];
            }
            else
            {
                storage._dim = [1, dim];
                storage._stride = [1, stride];
            }
        }

    @property size_t nrows() { return storage._dim[0]; }
    @property size_t ncols() { return storage._dim[1]; }

    public // Iterators
    {
        auto byRow()
        {
            return ByMatrixRow!(T, MatrixView!(T, false, true, storageOrder))(
                storage._dim, storage._stride, storage._data);
        }

        auto byCol()
        {
            return ByMatrixCol!(T, MatrixView!(T, true, false, storageOrder))(
                storage._dim, storage._stride, storage._data);
        }
    }

    public // Conversion to other types
    {
        static if(isVector)
        {
            auto opCast(Tresult)()
                if(!is(Tresult == T[]))
            {
                return cast(Tresult)(storage);
            }

            auto opCast(Tresult)()
                if(is(Tresult == T[]))
            {
                static if(multRow)
                    return sliceToArray!(ElementType, 1)(
                        [storage._dim[0]], [storage._stride[0]], storage._data);
                else
                    return sliceToArray!(ElementType, 1)(
                        [storage._dim[1]], [storage._stride[1]], storage._data);
            }
        }
        else
        {
            auto opCast(Tresult)()
            {
                return cast(Tresult)(storage);
            }
        }
    }

    public // Operations
    {
        bool opEquals(Tsource)(Tsource source)
            if(isStorage!(typeof(source.storage)))
        {
            return linalg.operations.compare(source.storage, storage);
        }

        auto opAssign(Tsource)(Tsource source)
            if(isStorage!(typeof(source.storage)))
        {
            linalg.operations.copy(source.storage, storage);
            return this;
        }

        auto opUnary(string op)()
            if(op == "+" || op == "-")
        {
            MatrixType result;
            linalg.operations.applyUnary!op(storage, result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(is(typeof(rhs.storage)) && isStorage!(typeof(rhs.storage)) &&
               (op == "+" || op == "-"))
        {
            MatrixType result;
            linalg.operations.applyBinary!op(storage,
                                             rhs.storage,
                                             result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(isMatrixOrView!(Trhs)
               && (op == "*"))
        {
            MatrixProductType!(MatrixView, Trhs) result;
            linalg.operations.matrixMult(storage,
                                         rhs.storage,
                                         result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(!isMatrixOrView!(Trhs) && is(ProductType!(ElementType, Trhs))
               && (op == "*"))
        {
            Matrix!(ProductType!(ElementType, Trhs),
                    nrowsP, ncolsP, storageOrder) result;
            linalg.operations.matrixMultScalar(storage, rhs,
                                               result.storage);
            return result;
        }

        auto opBinaryRight(string op, Tlhs)(Tlhs lhs)
            if(!isMatrixOrView!(Tlhs) && is(ProductType!(Tlhs, ElementType))
               && (op == "*"))
        {
            Matrix!(ProductType!(Tlhs, ElementType),
                    nrowsP, ncolsP, storageOrder) result;
            linalg.operations.matrixMultScalarR(lhs, storage,
                                                result.storage);
            return result;
        }

        auto transpose()
        {
            MatrixType result;
            linalg.operations.matrixTranspose(storage, result.storage);
            return result;
        }
    }
}

/** Matrix
*/
struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    alias Storage!(T, nrows_, ncols_, false, storageOrder_)
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
        static if(isResizeable)
            void setDimensions(in size_t[] dim...) pure {
                storage.setDimensions(dim); }
        auto byElement() { return storage.byElement(); }
    }

    enum size_t nrowsP = StorageType.dimPattern[0];
    enum size_t ncolsP = StorageType.dimPattern[1];

    enum bool isVector = (nrowsP == 1 || ncolsP == 1);
    enum bool multRow = (nrowsP != 1);
    enum bool multCol = (ncolsP != 1);

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

    @property size_t nrows() { return storage._dim[0]; }
    @property size_t ncols() { return storage._dim[1]; }

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

    public // Iterators
    {
        auto byRow()
        {
            return ByMatrixRow!(T, MatrixView!(T, false, true, storageOrder))(
                storage._dim, storage._stride, storage._data);
        }

        auto byCol()
        {
            return ByMatrixCol!(T, MatrixView!(T, true, false, storageOrder))(
                storage._dim, storage._stride, storage._data);
        }

        auto byBlock(size_t nr, size_t nc)
            in
            {
                assert((nrows % nr == 0) && (ncols % nc == 0));
            }
        body
        {
            return ByMatrixBlock!(T, MatrixView!(T, true, true, storageOrder))(
                [nr, nc], storage._dim, storage._stride, storage._data);
        }
    }

    public // Conversion to other types
    {
        static if(isVector)
        {
            auto opCast(Tresult)()
                if(!is(Tresult == T[]))
            {
                return cast(Tresult)(storage);
            }

            auto opCast(Tresult)()
                if(is(Tresult == T[]))
            {
                static if(multRow)
                    return sliceToArray!(ElementType, 1)(
                        [storage._dim[0]], [storage._stride[0]], storage._data);
                else
                    return sliceToArray!(ElementType, 1)(
                        [storage._dim[1]], [storage._stride[1]], storage._data);
            }
        }
        else
        {
            auto opCast(Tresult)()
            {
                return cast(Tresult)(storage);
            }
        }
    }

    public // Operations
    {
        bool opEquals(Tsource)(Tsource source)
            if(isStorage!(typeof(source.storage)))
        {
            return linalg.operations.compare(source.storage, storage);
        }

        auto opAssign(Tsource)(Tsource source)
            if(isStorage!(typeof(source.storage)))
        {
            linalg.operations.copy(source.storage, storage);
            return this;
        }

        auto opUnary(string op)()
            if(op == "+" || op == "-")
        {
            Matrix result;
            linalg.operations.applyUnary!op(storage, result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(is(typeof(rhs.storage)) && isStorage!(typeof(rhs.storage))
               && (op == "+" || op == "-"))
        {
            Matrix result;
            linalg.operations.applyBinary!op(storage,
                                             rhs.storage,
                                             result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(isMatrixOrView!(Trhs)
               && (op == "*"))
        {
            MatrixProductType!(Matrix, Trhs) result;
            linalg.operations.matrixMult(storage,
                                         rhs.storage,
                                         result.storage);
            return result;
        }

        auto opBinary(string op, Trhs)(Trhs rhs)
            if(!isMatrixOrView!(Trhs) && is(ProductType!(ElementType, Trhs))
               && (op == "*"))
        {
            Matrix!(ProductType!(ElementType, Trhs),
                    nrowsP, ncolsP, storageOrder) result;
            linalg.operations.matrixMultScalar(storage, rhs,
                                               result.storage);
            return result;
        }

        auto opBinaryRight(string op, Tlhs)(Tlhs lhs)
            if(!isMatrixOrView!(Tlhs) && is(ProductType!(Tlhs, ElementType))
               && (op == "*"))
        {
            Matrix!(ProductType!(Tlhs, ElementType),
                    nrowsP, ncolsP, storageOrder) result;
            linalg.operations.matrixMultScalarR(lhs, storage,
                                                result.storage);
            return result;
        }

        auto transpose()
        {
            Matrix result;
            linalg.operations.matrixTranspose(storage, result.storage);
            return result;
        }
    }

    /* Diagonalize matrix as symmetric */
    static if(is(typeof(linalg.operations.matrixSymmEigenval(storage))))
    {
        auto symmEigenval()
        {
            return linalg.operations.matrixSymmEigenval(storage);
        }

        auto symmEigenval(uint ilo, uint iup)
        {
            return linalg.operations.matrixSymmEigenval(storage, ilo, iup);
        }
    }
}

template isMatrixOrView(T)
{
    enum bool isMatrixOrView = isInstanceOf!(Matrix, T)
        || isInstanceOf!(MatrixView, T);
}

template ProductType(Tlhs, Trhs)
{
    alias typeof(*(new Tlhs) * *(new Trhs)) ProductType;
}

template MatrixProductType(Tlhs, Trhs)
{
    alias
        Matrix!(ProductType!(Tlhs.ElementType, Trhs.ElementType),
                Tlhs.nrowsP, Trhs.ncolsP,
                Tlhs.storageOrder)
        MatrixProductType;
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
        assert(a.nrows == 3);
        assert(a.ncols == 4);
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
    auto a = Matrix!(int, 3, 4, StorageOrder.colMajor)(array(iota(12)));
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
        foreach(v; a.byCol)
            result ~= [cast(int[]) v];
        assert(result == [[0, 4, 8],
                          [1, 5, 9],
                          [2, 6, 10],
                          [3, 7, 11]]);
    }

    // Transposed
    {
        auto a = Matrix!(int, 3, 4, StorageOrder.colMajor)(array(iota(12)));
        int[][] result = [];
        foreach(v; a.byRow)
            result ~= [cast(int[]) v];
        assert(result == [[0, 3, 6, 9],
                          [1, 4, 7, 10],
                          [2, 5, 8, 11]]);
        result = [];
        foreach(v; a.byCol)
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
        foreach(v; a[1..3][1..3].byCol)
            result ~= [cast(int[]) v];
        assert(result == [[5, 9],
                          [6, 10]]);
    }

    // Transposed
    {
        auto a = Matrix!(int, 3, 4, StorageOrder.colMajor)(array(iota(12)));
        int[][] result = [];
        foreach(v; a[1..3][1..3].byRow)
            result ~= [cast(int[]) v];
        assert(result == [[4, 7],
                          [5, 8]]);
        result = [];
        foreach(v; a[1..3][1..3].byCol)
            result ~= [cast(int[]) v];
        assert(result == [[4, 5],
                          [7, 8]]);
    }
}

unittest // Block iterator
{
    auto a = Matrix!(int, 6, 4)(array(iota(24)));
    int[][][] result = [];
    foreach(v; a.byBlock(3, 2))
        result ~= [cast(int[][]) v];
    assert(result == [[[0, 1],
                       [4, 5],
                       [8, 9]],
                      [[2, 3],
                       [6, 7],
                       [10, 11]],
                      [[12, 13],
                       [16, 17],
                       [20, 21]],
                      [[14, 15],
                       [18, 19],
                       [22, 23]]]);
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
    assert(cast(double[][]) (a1*2.)
           == [[0, 2, 4, 6],
               [8, 10, 12, 14],
               [16, 18, 20, 22]]);
    assert(cast(double[][]) (2.*a1)
           == [[0, 2, 4, 6],
               [8, 10, 12, 14],
               [16, 18, 20, 22]]);
    assert(cast(double[][]) (a1[0..2][1..3] * 2.)
           == [[2, 4],
               [10, 12]]);
    assert(cast(double[][]) (2. * a1[0..2][1..3])
           == [[2, 4],
               [10, 12]]);
}

unittest // Matrix multiplication
{
    auto a1 = Matrix!(int, 3, 2)(array(iota(6)));
    auto a2 = Matrix!(int, 2, 4)(array(iota(8)));
    assert(cast(int[][]) (a1 * a2)
           == [[4,  5,  6,  7],
               [12, 17, 22, 27],
               [20, 29, 38, 47]]);
    assert(cast(int[][]) (a1[0..2][] * a2[][0..2])
           == [[4,  5],
               [12, 17]]);
}

unittest // Matrix transposition
{
    auto a1 = Matrix!(int, 3, 2)(array(iota(6)));
    assert(cast(int[][]) (a1.transpose)
           == [[0, 3],
               [1, 4],
               [2, 5]]);
}

unittest // Diagonalization
{
    auto a1 = Matrix!(Complex!double, 3, 3)(
        [Complex!double(1, 0), Complex!double(0, 0), Complex!double(0, 0),
         Complex!double(0, 0), Complex!double(2, 0), Complex!double(0, 0),
         Complex!double(0, 0), Complex!double(0, 0), Complex!double(3, 0)]);
    double[] val;
    assert(a1.symmEigenval == [1, 2, 3]); //FIXME: may fail for low precision
    assert(a1.symmEigenval(1, 2) == [2, 3]); //FIXME: may fail for low precision
}
