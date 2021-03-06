// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013-2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.matrix;

public import linalg.misc.types;

import std.traits;

import oddsends;

import linalg.storage.regular1d;
import linalg.storage.regular2d;
import linalg.storage.slice;
import linalg.operations.basic;
import linalg.operations.conjugation;
import linalg.operations.multiplication;
import linalg.operations.eigen;
import linalg.operations.inversion;

debug import linalg.misc.debugging;

version(unittest)
{
    import std.array;
    import std.range;
    import std.math;
}

alias linalg.storage.slice.Slice Slice; //NOTE: waiting for proper slice support


private version(linalg_backend_lapack)
{
    version = linalg_backend_eigenval;
    version = linalg_backend_eigenvec;
}
private version(linalg_backend_mkl)
{
    version = linalg_backend_eigenval;
    version = linalg_backend_eigenvec;
}


/* Derive storage type for given matrix parameters */
private template MatrixStorageType(T, StorageOrder storageOrder,
                                   size_t nrows, size_t ncols)
{
    static if(nrows == 1)
        alias StorageRegular1D!(T, ncols) MatrixStorageType;
    else static if(ncols == 1)
        alias StorageRegular1D!(T, nrows) MatrixStorageType;
    else
        alias StorageRegular2D!(T, storageOrder, nrows, ncols)
            MatrixStorageType;
}

/**
 * Shape of matrix or vector
 */
enum MatrixShape
{
    row,
    col,
    matrix
}

/* Returns shape of matrix with given dimensions */
private auto shapeForDim(size_t[2] dim)
{
    if(dim[0] == 1)
        return MatrixShape.row;
    else if(dim[1] == 1)
        return MatrixShape.col;
    else
        return MatrixShape.matrix;
}

template Matrix(T, size_t nrows_, size_t ncols_,
                StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicMatrix!(T, nrows_, ncols_, storageOrder_, false) Matrix;
}

template MatrixView(T, size_t nrows_, size_t ncols_,
                    StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicMatrix!(T, nrows_, ncols_, storageOrder_, true) MatrixView;
}

/**
 * Matrix or vector or view.
 */
struct BasicMatrix(T, size_t nrows_, size_t ncols_,
                   StorageOrder storageOrder_, bool isBound)
{
    /** Dimensions pattern */
    enum size_t[2] dimPattern = [nrows_, ncols_];

    /* Select storage type.
     * Note: vectors use 1d storage (mainly for optimization)
     */
    alias MatrixStorageType!(T, storageOrder_, nrows_, ncols_)
        StorageType;
    /** Type of matrix elements */
    alias StorageType.ElementType ElementType;
    /** Shape of the matrix or vector */
    enum auto shape = shapeForDim(dimPattern);
    /** Whether this is vector */
    enum bool isVector = shape != MatrixShape.matrix;
    /** Storage order */
    enum StorageOrder storageOrder = storageOrder_;
    enum MemoryManag memoryManag =
        StorageType.isStatic ? MemoryManag.stat : (
            isBound ? MemoryManag.bound : MemoryManag.dynamic);
    enum bool isStatic = (memoryManag == MemoryManag.stat);

    /**
     * Storage of matrix data.
     * This field is public to allow direct access to matrix data storage
     * if optimization is needed.
     */
    public StorageType storage;

    /* Constructors
     */

    /* Creates matrix for storage. For internal use only.
     * Public because used by ranges.
     */
    this()(auto ref StorageType storage) pure
    {
        this.storage = storage;
    }

    /**
     * If matrix is static then create a copy of the source.
     * Otherwise share the source data.
     */
    this(Tsource)(auto ref Tsource source) pure
        if(isMatrix!Tsource)
    {
        this = source;
    }

    static if(isStatic)
    {
        /** Create static shallow copy of array and wrap it. */
        this()(ElementType[] array) pure
        {
            storage = StorageType(array);
        }
    }
    else
    {
        static if(isVector)
        {
            /** Create vector wrapping array */
            this()(ElementType[] array) pure
            {
                this(StorageType(array));
            }

            /** Allocate new vector of given length */
            this()(size_t dim) pure
            {
                this(StorageType(dim));
            }

            /** Allocate new vector with given dimensions */
            /* This constructor allows set vector and matrix dimensions
             * uniformly to avoid spawning shape tests.
             */
            this()(size_t nrows, size_t ncols) pure
            {
                static if(shape == MatrixShape.row)
                {
                    assert(nrows == 1);
                    this(ncols);
                }
                else
                {
                    assert(ncols == 1);
                    this(nrows);
                }
            }
        }
        else
        {
            /** Allocate new matrix with given dimensions */
            this()(size_t nrows, size_t ncols) pure
            {
                this(StorageType([nrows, ncols]));
            }

            /** Wrap array with a matrix with given dimensions */
            this()(ElementType[] array,
                 size_t nrows, size_t ncols) pure
            {
                this(StorageType(array, [nrows, ncols]));
            }
        }
    }

    public // Dimensions
    {
        /* Vector also has rows and columns since we distinguish
         * row and column vectors
         */
        static if(shape == MatrixShape.matrix)
        {
            /** Dimensions of matrix */
            @property size_t nrows() pure const { return storage.nrows; }
            @property size_t ncols() pure const { return storage.ncols; } //ditto
        }
        else static if(shape == MatrixShape.row)
        {
            enum size_t nrows = 1;
            @property size_t ncols() pure const { return storage.length; }
        }
        else static if(shape == MatrixShape.col)
        {
            @property size_t nrows() pure const { return storage.length; }
            enum size_t ncols = 1;
        }
        else static assert(false);
        /** Dimensions of matrix */
        @property size_t[2] dim() pure const { return [nrows, ncols]; }

        /** Test dimensions for compatibility */
        static bool isCompatDim(in size_t[2] dim) pure
        {
            static if(shape == MatrixShape.matrix)
                return StorageType.isCompatDim(dim);
            else static if(shape == MatrixShape.row)
                return dim[0] == 1 && StorageType.isCompatDim(dim[1]);
            else static if(shape == MatrixShape.col)
                return dim[1] == 1 && StorageType.isCompatDim(dim[0]);
        }

        static if(!isStatic)
        {
            static if(isVector)
                /** Set length of vector */
                void setDim(size_t dim) pure
                {
                    storage.setDim(dim);
                }

            /** Set dimensions of matrix or vector */
            void setDim(in size_t[2] dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                static if(shape == MatrixShape.matrix)
                    storage.setDim(dim);
                else static if(shape == MatrixShape.row)
                    setDim(dim[1]);
                else static if(shape == MatrixShape.col)
                    setDim(dim[0]);
            }
        }
    }

    public // Slices and indices support
    {
        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure
        {
            return storage.opDollar!dimIndex;
        }

        static if(isVector)
        {
            ref auto opIndex() pure
            {
                return MatrixView!(ElementType,
                                   dimPattern[0] == 1 ? 1 : dynsize,
                                   dimPattern[1] == 1 ? 1 : dynsize,
                                   storageOrder)(storage.opIndex());
            }

            ref auto opIndex(size_t i) pure
            {
                return storage[i];
            }

            ref auto opIndex(Slice s) pure
            {
                return MatrixView!(ElementType,
                                   dimPattern[0] == 1 ? 1 : dynsize,
                                   dimPattern[1] == 1 ? 1 : dynsize,
                                   storageOrder)(storage.opIndex(s));
            }
        }
        else
        {
            ref auto opIndex() pure
            {
                return MatrixView!(ElementType,
                                   dimPattern[0] == 1 ? 1 : dynsize,
                                   dimPattern[1] == 1 ? 1 : dynsize,
                                   storageOrder)(storage.opIndex());
            }

            ref auto opIndex(size_t irow, size_t icol) pure
            {
                return storage[irow, icol];
            }

            ref auto opIndex(Slice srow, size_t icol) pure
            {
                return MatrixView!(ElementType,
                                   dynsize, 1,
                                   storageOrder)(
                                       storage.opIndex(srow, icol));
            }

            ref auto opIndex(size_t irow, Slice scol) pure
            {
                return MatrixView!(ElementType,
                                   1, dynsize,
                                   storageOrder)(
                                       storage.opIndex(irow, scol));
            }

            ref auto opIndex(Slice srow, Slice scol) pure
            {
                return MatrixView!(ElementType,
                                   dynsize, dynsize,
                                   storageOrder)(
                                       storage.opIndex(srow, scol));
            }
        }
    }

    /* Cast to built-in array */
    static if(isVector)
    {
        auto opCast(Tcast)() pure
            if(is(Tcast == ElementType[]))
        {
            return cast(Tcast) storage;
        }

        auto opCast(Tcast)() pure
            if(is(Tcast == ElementType[][]))
        {
            return cast(Tcast)
                StorageRegular2D!(ElementType,
                                  shape == MatrixShape.row
                                  ? StorageOrder.row
                                  : StorageOrder.col,
                                  dynsize, dynsize)(storage);
        }
    }
    else
    {
        ElementType[][] opCast() pure
        {
            return cast(typeof(return)) storage;
        }
    }

    /** Create shallow copy of matrix */
    @property auto dup() pure
    {
        auto result = Matrix!(ElementType,
                              dimPattern[0] == 1 ? 1 : dynsize,
                              dimPattern[1] == 1 ? 1 : dynsize,
                              storageOrder)(this.nrows, this.ncols);
        copy(this.storage, result.storage);
        return result;
    }
    
    public // Operations
    {
        ref auto opAssign(Tsource)(auto ref Tsource source) pure
            if(isMatrix!Tsource)
        {
            static if(memoryManag == MemoryManag.dynamic)
                this.storage = typeof(this.storage)(source.storage);
            else
                copy(source.storage, this.storage);
            return this;
        }

        bool opEquals(Tsource)(auto ref Tsource source) pure
            if(isMatrix!Tsource)
        {
            return compare(source.storage, this.storage);
        }

        /* Unary operations
         */

        ref auto opUnary(string op)() pure
            if(op == "+")
        {
            return this;
        }

        ref auto opUnary(string op)() pure
            if(op == "-")
        {
            static if(memoryManag == MemoryManag.stat)
                BasicMatrix dest;
            else
                auto dest = Matrix!(ElementType,
                                    dimPattern[0], dimPattern[1],
                                    storageOrder)(nrows, ncols);
            linalg.operations.basic.map!("-a")(this.storage, dest.storage);
            return dest;
        }

        /* Matrix addition and subtraction
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref Tsource source) pure
            if(isMatrix!Tsource && (op == "+" || op == "-"))
        {
            linalg.operations.basic.zip!("a"~op~"b")(
                this.storage, source.storage, this.storage);
            return this;
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(isMatrix!Trhs && (op == "+" || op == "-"))
        {
            TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
            static if(dest.memoryManag == MemoryManag.dynamic)
                dest.setDim([this.nrows, this.ncols]);
            linalg.operations.basic.zip!("a"~op~"b")(
                this.storage, rhs.storage, dest.storage);
            return dest;
        }

        /* Multiplication by scalar
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref Tsource source) pure
            if(!(isMatrix!Tsource) && (op == "*" || op == "/")
               && is(TypeOfOp!(ElementType, op, Tsource) == ElementType))
        {
            linalg.operations.basic.map!((a, b) => mixin("a"~op~"b"))(
                this.storage, this.storage, source);
            return this;
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(!(isMatrix!Trhs) && (op == "*" || op == "/"))
        {
            TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
            static if(typeof(dest).memoryManag == MemoryManag.dynamic)
                dest.setDim([this.nrows, this.ncols]);
            linalg.operations.basic.map!((a, rhs) => mixin("a"~op~"rhs"))(
                this.storage, dest.storage, rhs);
            return dest;
        }

        /* Multiplication between matrix elements and scalar
         * can be non-commutative
         */
        auto opBinaryRight(string op, Tlhs)(
            auto ref Tlhs lhs) pure
            if(!(isMatrix!Tlhs) && op == "*")
        {
            TypeOfResultMatrix!(Tlhs, op, typeof(this)) dest;
            static if(typeof(dest).memoryManag == MemoryManag.dynamic)
                dest.setDim([this.nrows, this.ncols]);
            linalg.operations.basic.map!((a, lhs) => mixin("lhs"~op~"a"))(
                this.storage, dest.storage, lhs);
            return dest;
        }

        /* Matrix multiplication
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref Tsource source) pure
            if(isMatrix!Tsource && op == "*")
        {
            return (this = this * source);
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(isMatrix!Trhs && op == "*")
        {
            static if(this.shape == MatrixShape.row
                      && rhs.shape == MatrixShape.col)
            {
                return mulRowCol(this.storage, rhs.storage);
            }
            else
            {
                TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
                static if(typeof(dest).memoryManag == MemoryManag.dynamic)
                    dest.setDim([this.nrows, rhs.ncols]);
                static if(this.shape == MatrixShape.row)
                {
                    static if(rhs.shape == MatrixShape.matrix)
                        mulRowMat(this.storage, rhs.storage, dest.storage);
                    else static assert(false);
                }
                else static if(this.shape == MatrixShape.col)
                {
                    static if(rhs.shape == MatrixShape.row)
                        mulColRow(this.storage, rhs.storage, dest.storage);
                    else static if(rhs.shape == MatrixShape.matrix)
                        mulColMat(this.storage, rhs.storage, dest.storage);
                    else static assert(false);
                }
                else static if(this.shape == MatrixShape.matrix)
                {
                    static if(rhs.shape == MatrixShape.col)
                        mulMatCol(this.storage, rhs.storage, dest.storage);
                    else static if(rhs.shape == MatrixShape.matrix)
                        mulMatMat(this.storage, rhs.storage, dest.storage);
                    else static assert(false);
                }
                else static assert(false);
                return dest;
            }
        }
    }

    // Diagonalization
    public static if(!isVector)
    {
        /**
         * Return all eigenvalues.
         *
         * Only upper-triangle part is used.
         * Contents of matrix will be modified.
         */
        auto symmEigenval()() pure
        {
            return matrixSymmEigenval(this.storage);
        }

        /**
         * Return eigenvalues in given range
         * (ascending order, starts from 0, includes borders).
         *
         * Only upper-triangle part is used.
         * Contents of matrix will be modified.
         */
        auto symmEigenval()(size_t ilo, size_t iup) pure
        {
            return matrixSymmEigenval(this.storage, ilo, iup);
        }

        /**
         * Return eigenvalues in given range
         * and corresponding eigenvectors.
         *
         * Only upper-triangle part is used.
         * Contents of matrix will be modified.
         */
        auto symmEigenAll()(size_t ilo, size_t iup) pure
        {
            return matrixSymmEigenAll(this.storage, ilo, iup);
        }
    }

    public // Other operations
    {
        /**
         * Return transposed matrix for real matrix or
         * conjugated and transposed matrix for complex matrix.
         */
        @property ref auto conj() pure
        {
            //FIXME: Will fail if conjugation changes type
            Matrix!(ElementType, dimPattern[1], dimPattern[0], storageOrder) dest;
            static if(typeof(dest).memoryManag == MemoryManag.dynamic)
                dest.setDim([this.ncols, this.nrows]);
            conjMatrix(this.storage, dest.storage);
            return dest;
        }

        ref auto inverse()() pure
        {
            Matrix!(typeof(1 / this[0, 0]), dimPattern[0], dimPattern[1],
                    storageOrder) dest;
            matrixInverse(this.storage, dest.storage);
            return dest;
        }

        void fillZero()() pure
        {
            fill(zero!(ElementType), this.storage);
        }
    }

    public // Ranges
    {
        @property auto byElement() pure
        {
            return storage.byElement();
        }

        static if(!isVector)
        {
            @property auto byRow() pure
            {
                return InputRangeWrapper!(
                    typeof(storage.byRow),
                    MatrixView!(ElementType, 1, dynsize, storageOrder))(
                        storage.byRow);
            }

            @property auto byCol() pure
            {
                return InputRangeWrapper!(
                    typeof(storage.byCol),
                    MatrixView!(ElementType, dynsize, 1, storageOrder))(
                        storage.byCol);
            }

            @property auto byBlock(size_t[2] subdim) pure
            {
                return InputRangeWrapper!(
                    typeof(storage.byBlock(subdim)),
                    MatrixView!(ElementType, dynsize, dynsize, storageOrder))(
                        storage.byBlock(subdim));
            }
        }
    }
}

/**
 * Detect whether T is matrix
 */
template isMatrix(T)
{
    enum bool isMatrix = isInstanceOf!(BasicMatrix, T);
}

/* Derive result type for matrix operations */
private template TypeOfResultMatrix(Tlhs, string op, Trhs)
{
    static if(isMatrix!Tlhs && isMatrix!Trhs)
    {
        static if(op == "+" || op == "-")
            alias Matrix!(TypeOfOp!(Tlhs.ElementType,
                                    op, Trhs.ElementType),
                          Tlhs.dimPattern[0] == 1 ? 1 : dynsize,
                          Tlhs.dimPattern[1] == 1 ? 1 : dynsize,
                          Tlhs.storageOrder) TypeOfResultMatrix;
        else static if(op == "*")
            alias Matrix!(TypeOfOp!(Tlhs.ElementType,
                                    op, Trhs.ElementType),
                          Tlhs.dimPattern[0] == 1 ? 1 : dynsize,
                          Trhs.dimPattern[1] == 1 ? 1 : dynsize,
                          Tlhs.storageOrder) TypeOfResultMatrix;
        else
            alias void TypeOfResultMatrix;
    }
    else static if(isMatrix!Tlhs && (op == "*" || op == "/"))
         alias Matrix!(TypeOfOp!(Tlhs.ElementType, op, Trhs),
                       Tlhs.dimPattern[0],
                       Tlhs.dimPattern[1],
                       Tlhs.storageOrder) TypeOfResultMatrix;
    else static if(isMatrix!Trhs && (op == "*"))
         alias Matrix!(TypeOfOp!(Tlhs, op, Trhs.ElementType),
                       Trhs.dimPattern[0],
                       Trhs.dimPattern[1],
                       Trhs.storageOrder) TypeOfResultMatrix;
    else
        alias void TypeOfResultMatrix;
}

public // Map function
{
    /**
     * Map pure function over matrix.
     */
    auto map(alias fun, Tsource, Targs...)(
         auto ref Tsource source,
         auto ref Targs args)
        if(isMatrix!Tsource)
    {
        Matrix!(typeof(fun(source[0, 0], args)),
                Tsource.dimPattern[0], Tsource.dimPattern[1],
                Tsource.storageOrder) dest;
        static if(dest.memoryManag == MemoryManag.dynamic)
            dest.setDim([source.nrows, source.ncols]);
        linalg.operations.basic.map!(fun)(source.storage, dest.storage, args);
        return dest;
    }
}

unittest // Type properties
{
    alias Matrix!(int, 2, 3) Mi23;
    alias Matrix!(int, 2, 3, StorageOrder.row) Mi23r;
    alias Matrix!(int, 2, 3, StorageOrder.col) Mi23c;
    alias Matrix!(int, dynsize, 3) Mid3;
    alias Matrix!(int, 1, 3) Mi13;
    alias Matrix!(int, 2, 1) Mi21;
    alias Matrix!(int, dynsize, dynsize) Midd;
    alias Matrix!(int, 1, dynsize) Mi1d;
    alias Matrix!(int, dynsize, 1) Mid1;

    // dimPattern
    static assert(Mi23.dimPattern == [2, 3]);
    static assert(Mid3.dimPattern == [dynsize, 3]);

    // shape
    static assert(Mi23.shape == MatrixShape.matrix);
    static assert(Mi13.shape == MatrixShape.row);
    static assert(Mi21.shape == MatrixShape.col);
    static assert(Midd.shape == MatrixShape.matrix);
    static assert(Mi1d.shape == MatrixShape.row);
    static assert(Mid1.shape == MatrixShape.col);

    // isVector
    static assert(!(Mi23.isVector));
    static assert(Mi13.isVector);
    static assert(Mi21.isVector);
    static assert(!(Midd.isVector));
    static assert(Mi1d.isVector);
    static assert(Mid1.isVector);

    // storageOrder
    static assert(Mi23.storageOrder == defaultStorageOrder);
    static assert(Mi23r.storageOrder == StorageOrder.row);
    static assert(Mi23c.storageOrder == StorageOrder.col);

    // ElementType
    static assert(is(Mi23.ElementType == int));

    // isStatic
    static assert(Mi23.isStatic);
    static assert(!(Mid3.isStatic));
    static assert(!(Mi1d.isStatic));
    static assert(!(Midd.isStatic));
}

unittest // Constructors, cast
{
    debug mixin(debugUnittestBlock("Constructors & cast"));

    int[] a = [1, 2, 3, 4, 5, 6];

    assert(cast(int[][]) Matrix!(int, dynsize, dynsize)(
               StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
                   a, [2, 3]))
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) Matrix!(int, 2, 3)(a)
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) Matrix!(int, 1, 3)(a[0..3])
           == [[1, 2, 3]]);
    assert(cast(int[][]) Matrix!(int, 3, 1)(a[0..3])
           == [[1],
               [2],
               [3]]);
    assert(cast(int[][]) Matrix!(int, 1, dynsize)(a[0..3])
           == [[1, 2, 3]]);
    assert(cast(int[][]) Matrix!(int, dynsize, 1)(a[0..3])
           == [[1],
               [2],
               [3]]);
    assert(cast(int[][]) Matrix!(int, 1, dynsize)(3)
           == [[0, 0, 0]]);
    assert(cast(int[][]) Matrix!(int, 1, dynsize)(1, 3)
           == [[0, 0, 0]]);
    assert(cast(int[][]) Matrix!(int, dynsize, dynsize)(2, 3)
           == [[0, 0, 0],
               [0, 0, 0]]);
    assert(cast(int[][]) Matrix!(int, dynsize, dynsize)(2, 3)
           == [[0, 0, 0],
               [0, 0, 0]]);
    assert(cast(int[][]) Matrix!(int, dynsize, dynsize)(a, 2, 3)
           == [[1, 2, 3],
               [4, 5, 6]]);
    auto ma = Matrix!(int, 2, 3)(a);
    {
        Matrix!(int, 2, 3) mb = ma;
        assert(cast(int[][]) mb
               == [[1, 2, 3],
                   [4, 5, 6]]);
    }
    {
        Matrix!(int, dynsize, dynsize) mb = ma;
        assert(cast(int[][]) mb
               == [[1, 2, 3],
                   [4, 5, 6]]);
    }
}

unittest // Storage direct access
{
    debug mixin(debugUnittestBlock("Storage direct access"));

    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = Matrix!(int, dynsize, dynsize, StorageOrder.row)(src, 2, 3);
    assert(a.storage.container.ptr == src.ptr);
    assert(a.storage.container == [1, 2, 3, 4, 5, 6]);
    assert(a.storage.dim == [2, 3]);
    assert(a.storage.stride == [3, 1]);
}

unittest // Dimension control
{
    debug mixin(debugUnittestBlock("Dimension control"));

    Matrix!(int, dynsize, dynsize) a;
    //assert(a.empty);
    assert(a.nrows == 0);
    assert(a.ncols == 0);
    assert(a.dim == [0, 0]);
    a.setDim([2, 3]);
    //assert(!(a.empty));
    assert(a.nrows == 2);
    assert(a.ncols == 3);
    assert(a.dim == [2, 3]);
    assert(a.isCompatDim([22, 33]));

    Matrix!(int, 2, 3) b;
    //assert(!(b.empty));
    assert(b.nrows == 2);
    assert(b.ncols == 3);
    assert(b.dim == [2, 3]);
    assert(!(b.isCompatDim([22, 33])));
}

unittest // Comparison
{
    debug mixin(debugUnittestBlock("Comparison"));

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [6, 5, 4, 3, 2, 1];

    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, 2, 3)(src1);
        auto c = Matrix!(int, 2, 3)(src2);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto c = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto c = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        assert(a == b);
        assert(a != c);
    }
}

unittest // Copying
{
    debug mixin(debugUnittestBlock("Copying"));

    int[] src = [1, 2, 3, 4, 5, 6];
    int[] msrc = src.dup;

    {
        auto a = Matrix!(int, 2, 3)(src);
        Matrix!(int, 2, 3) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Matrix!(int, 2, 3)(msrc);
        Matrix!(int, dynsize, dynsize) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Matrix!(int, 2, 3)(src);
        Matrix!(int, dynsize, dynsize) b;
        auto c = (b = a.dup);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(msrc, 2, 3);
        Matrix!(int, 2, 3) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(msrc, 2, 3);
        Matrix!(int, dynsize, dynsize) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(msrc, 2, 3);
        Matrix!(int, dynsize, dynsize) b;
        auto c = (b = a.dup);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
}

unittest // Regular indices
{
    debug mixin(debugUnittestBlock("Regular indices"));

    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(a[1, 2] == 8);
    assert((a[1, 2] = 80) == 80);
    assert(a[1, 2] == 80);
    ++a[1, 2];
    assert(a[1, 2] == 81);
    a[1, 2] += 3;
    assert(a[1, 2] == 84);
}

unittest // Slices
{
    debug mixin(debugUnittestBlock("Slices"));

    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(cast(int[][]) a[1, Slice(1, 5)]
           == [[7, 8, 9, 10]]);
    assert(cast(int[][]) a[Slice(1, 4), 1]
           == [[7],
               [13],
               [19]]);
    assert(cast(int[][]) a[Slice(1, 4), Slice(1, 5)]
           == [[7, 8, 9, 10],
               [13, 14, 15, 16],
               [19, 20, 21, 22]]);
    assert(cast(int[][]) a[1, Slice(1, 5, 3)]
           == [[7, 10]]);
    assert(cast(int[][]) a[Slice(1, 4, 2), 1]
           == [[7],
               [19]]);
    assert(cast(int[][]) a[Slice(1, 4, 2), Slice(1, 5, 3)]
           == [[7, 10],
               [19, 22]]);

    a[Slice(1, 4, 2), Slice(1, 5, 3)] =
        Matrix!(int, 2, 2)(array(iota(101, 105)));
    assert(cast(int[][]) a[]
           == [[0, 1, 2, 3, 4, 5],
               [6, 101, 8, 9, 102, 11],
               [12, 13, 14, 15, 16, 17],
               [18, 103, 20, 21, 104, 23]]);
}

unittest // Unary + and -
{
    debug mixin(debugUnittestBlock("Unary + and -"));

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = Matrix!(int, 2, 3)(src);
        assert(cast(int[][]) (+a) == [[1, 2, 3],
                                      [4, 5, 6]]);
        assert(cast(int[][]) (-a) == [[-1, -2, -3],
                                      [-4, -5, -6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src, 2, 3);
        assert(cast(int[][]) (+a) == [[1, 2, 3],
                                      [4, 5, 6]]);
        assert(cast(int[][]) (-a) == [[-1, -2, -3],
                                      [-4, -5, -6]]);
    }
}

unittest // Matrix += and -=
{
    debug mixin(debugUnittestBlock("Matrix += and -="));

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [7, 8, 9, 10, 11, 12];
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, 2, 3)(src2);
        a += b;
        assert(cast(int[][]) a == [[8, 10, 12],
                                   [14, 16, 18]]);
        a -= b;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1.dup, 2, 3);
        auto b = Matrix!(int, 2, 3)(src2);
        a += b;
        assert(cast(int[][]) a == [[8, 10, 12],
                                   [14, 16, 18]]);
        a -= b;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        a += b;
        assert(cast(int[][]) a == [[8, 10, 12],
                                   [14, 16, 18]]);
        a -= b;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        a += b;
        assert(cast(int[][]) a == [[8, 10, 12],
                                   [14, 16, 18]]);
        a -= b;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
}

unittest // Matrix + and -
{
    debug mixin(debugUnittestBlock("Matrix + and -"));

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [11, 22, 33, 44, 55, 66];
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, 2, 3)(src2);
        auto c = a + b;
        assert(cast(int[][]) c == [[12, 24, 36],
                                   [48, 60, 72]]);
        c = b - a;
        assert(cast(int[][]) c == [[10, 20, 30],
                                   [40, 50, 60]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, 2, 3)(src2);
        auto c = a + b;
        assert(cast(int[][]) c == [[12, 24, 36],
                                   [48, 60, 72]]);
        c = b - a;
        assert(cast(int[][]) c == [[10, 20, 30],
                                   [40, 50, 60]]);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        auto c = a + b;
        assert(cast(int[][]) c == [[12, 24, 36],
                                   [48, 60, 72]]);
        c = b - a;
        assert(cast(int[][]) c == [[10, 20, 30],
                                   [40, 50, 60]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        auto c = a + b;
        assert(cast(int[][]) c == [[12, 24, 36],
                                   [48, 60, 72]]);
        c = b - a;
        assert(cast(int[][]) c == [[10, 20, 30],
                                   [40, 50, 60]]);
    }
}

unittest // Matrix *= scalar
{
    debug mixin(debugUnittestBlock("Matrix *= scalar"));

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = Matrix!(int, 2, 3)(src);
        a *= 2;
        assert(cast(int[][]) a == [[2, 4, 6],
                                   [8, 10, 12]]);
        a /= 2;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src, 2, 3);
        a *= 2;
        assert(cast(int[][]) a == [[2, 4, 6],
                                   [8, 10, 12]]);
        a /= 2;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
}

unittest // Matrix * scalar
{
    debug mixin(debugUnittestBlock("Matrix * scalar"));

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = Matrix!(int, 2, 3)(src);
        auto b = a * 2;
        assert(cast(int[][]) b == [[2, 4, 6],
                                   [8, 10, 12]]);
        Matrix!(int, 2, 3) c;
        c = b;
        b = c / 2;
        assert(cast(int[][]) b == [[1, 2, 3],
                                   [4, 5, 6]]);
        b = 2 * a;
        assert(cast(int[][]) b == [[2, 4, 6],
                                   [8, 10, 12]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src, 2, 3);
        auto b = a * 2;
        assert(cast(int[][]) b == [[2, 4, 6],
                                   [8, 10, 12]]);
        Matrix!(int, dynsize, dynsize) c = b;
        c = b;
        b = c / 2;
        assert(cast(int[][]) b == [[1, 2, 3],
                                   [4, 5, 6]]);
        b = 2 * a;
        assert(cast(int[][]) b == [[2, 4, 6],
                                   [8, 10, 12]]);
    }
}

unittest // Matrix *=
{
    debug mixin(debugUnittestBlock("Matrix *="));

    {
        int[] src1 = [1, 2, 3, 4];
        int[] src2 = [7, 8, 9, 10];
        auto a = Matrix!(int, 2, 2)(src1);
        auto b = Matrix!(int, 2, 2)(src2);
        a *= b;
        assert(cast(int[][]) a == [[25, 28],
                                   [57, 64]]);
    }
    {
        int[] src1 = [1, 2, 3, 4, 5, 6];
        int[] src2 = [7, 8, 9, 10, 11, 12];
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, 3, 2)(src2);
        a *= b;
        assert(cast(int[][]) a == [[58, 64],
                                   [139, 154]]);
    }
    {
        int[] src1 = [1, 2, 3, 4];
        int[] src2 = [7, 8, 9, 10];
        auto a = Matrix!(int, 2, 2)(src1);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 2);
        a *= b;
        assert(cast(int[][]) a == [[25, 28],
                                   [57, 64]]);
    }
    {
        int[] src1 = [1, 2, 3, 4, 5, 6];
        int[] src2 = [7, 8, 9, 10, 11, 12];
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 3, 2);
        a *= b;
        assert(cast(int[][]) a == [[58, 64],
                                   [139, 154]]);
    }
}

unittest // Matrix *
{
    debug mixin(debugUnittestBlock("Matrix *"));

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [7, 8, 9, 10, 11, 12];
    {
        auto a = Matrix!(int, 1, 3)(src1[0..3]);
        auto b = Matrix!(int, 3, 1)(src2[0..3]);
        auto c = a * b;
        assert(c == 1*7 + 2*8 + 3*9);
        auto d = b * a;
        assert(cast(int[][]) d == [[7*1, 7*2, 7*3],
                                   [8*1, 8*2, 8*3],
                                   [9*1, 9*2, 9*3]]);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, 3, 1)(src2[0..3]);
        auto c = a * b;
        assert(cast(int[][]) c == [[50],
                                   [122]]);
    }
    {
        auto a = Matrix!(int, 1, 3)(src1[0..3]);
        auto b = Matrix!(int, 3, 2)(src2);
        auto c = a * b;
        assert(cast(int[][]) c == [[58, 64]]);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, 3, 2)(src2);
        auto c = a * b;
        assert(cast(int[][]) c == [[58, 64],
                                   [139, 154]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, 3, 2)(src2);
        auto c = a * b;
        assert(cast(int[][]) c == [[58, 64],
                                   [139, 154]]);
    }
    {
        auto a = Matrix!(int, 2, 3)(src1);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 3, 2);
        auto c = a * b;
        assert(cast(int[][]) c == [[58, 64],
                                   [139, 154]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 3, 2);
        auto c = a * b;
        assert(cast(int[][]) c == [[58, 64],
                                   [139, 154]]);
    }
}

unittest // Ranges
{
    debug mixin(debugUnittestBlock("Ranges"));

    int[] src = [1, 2, 3, 4, 5, 6];
    {
        auto a = Matrix!(int, 2, 3)(src);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 2, 3, 4, 5, 6]);
        }
        {
            int[][] result = [];
            foreach(r; a.byRow)
                result ~= [cast(int[]) r];
            assert(result == [[1, 2, 3],
                              [4, 5, 6]]);
        }
        {
            int[][] result = [];
            foreach(r; a.byCol)
                result ~= [cast(int[]) r];
            assert(result == [[1, 4],
                              [2, 5],
                              [3, 6]]);
        }
        {
            int[] src1 = [1, 2, 3, 4, 5, 6,
                                    7, 8, 9, 10, 11, 12,
                                    13, 14, 15, 16, 17, 18,
                                    19, 20, 21, 22, 23, 24];
            auto b = Matrix!(int, 4, 6)(src1);
            int[][][] result = [];
            foreach(r; b.byBlock([2, 3]))
                result ~= [cast(int[][]) r];
            assert(result == [[[1, 2, 3],
                               [7, 8, 9]],
                              [[4, 5, 6],
                               [10, 11, 12]],
                              [[13, 14, 15],
                               [19, 20, 21]],
                              [[16, 17, 18],
                               [22, 23, 24]]]);
        }
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src, 2, 3);
        {
            int[] result = [];
            foreach(r; a.byElement)
                result ~= [r];
            assert(result == [1, 2, 3, 4, 5, 6]);
        }
        {
            int[][] result = [];
            foreach(r; a.byRow)
                result ~= [cast(int[]) r];
            assert(result == [[1, 2, 3],
                              [4, 5, 6]]);
        }
        {
            int[][] result = [];
            foreach(r; a.byCol)
                result ~= [cast(int[]) r];
            assert(result == [[1, 4],
                              [2, 5],
                              [3, 6]]);
        }
        {
            int[] src1 = [1, 2, 3, 4, 5, 6,
                                    7, 8, 9, 10, 11, 12,
                                    13, 14, 15, 16, 17, 18,
                                    19, 20, 21, 22, 23, 24];
            auto b = Matrix!(int, dynsize, dynsize)(src1, 4, 6);
            int[][][] result = [];
            foreach(r; b.byBlock([2, 3]))
                result ~= [cast(int[][]) r];
            assert(result == [[[1, 2, 3],
                               [7, 8, 9]],
                              [[4, 5, 6],
                               [10, 11, 12]],
                              [[13, 14, 15],
                               [19, 20, 21]],
                              [[16, 17, 18],
                               [22, 23, 24]]]);
        }
    }
}

unittest // Diagonalization
{
    debug mixin(debugUnittestBlock("Diagonalization"));

    alias Complex!double C;
    auto a = Matrix!(C, 3, 3)(
        [C(1, 0), C(0, 0), C(0, 0),
         C(0, 0), C(2, 0), C(0, 0),
         C(0, 0), C(0, 0), C(3, 0)]);
    double[] val;
    auto b = a.dup;
    version(linalg_backend_eigenval)
    {
        assert(a.symmEigenval().approxEqual([1, 2, 3]));
        assert(b.symmEigenval(1, 2).approxEqual([2, 3]));
    }
    version(linalg_backend_eigenvec)
    {
        auto result = a.symmEigenAll(1, 2);
        assert(result[0] == [2, 3]);
        assert(result[1] == [[C(0), C(1), C(0)],
                             [C(0), C(0), C(1)]]);
    }
}

unittest // Map function
{
    debug mixin(debugUnittestBlock("Map function"));

    int b = 2;
    assert(cast(int[][]) map!((a, b) => a*b)(
               Matrix!(int, 3, 4)(array(iota(12))), b)
           == [[0, 2, 4, 6],
               [8, 10, 12, 14],
               [16, 18, 20, 22]]);
}

unittest // Hermitian conjugation
{
    debug mixin(debugUnittestBlock("Hermitian conjugation"));

    assert(cast(int[][]) (Matrix!(int, 3, 4)(array(iota(12))).conj())
           == [[0, 4, 8],
               [1, 5, 9],
               [2, 6, 10],
               [3, 7, 11]]);

    alias Complex!double C;
    //FIXME: may fail for low precision
    assert(cast(C[][]) (Matrix!(C, 2, 3)(
                            [C(1, 1), C(1, 2), C(1, 3),
                             C(2, 1), C(2, 2), C(2, 3)]).conj())
           == [[C(1, -1), C(2, -1)],
               [C(1, -2), C(2, -2)],
               [C(1, -3), C(2, -3)]]);

    assert(cast(int[][]) (Matrix!(int, 1, 4)(array(iota(4))).conj())
           == [[0],
               [1],
               [2],
               [3]]);

    //FIXME: may fail for low precision
    assert(cast(C[][]) (Matrix!(C, 1, 3)(
                            [C(1, 1), C(1, 2), C(1, 3)]).conj())
           == [[C(1, -1)],
               [C(1, -2)],
               [C(1, -3)]]);
}

unittest // Inversion
{
    debug mixin(debugUnittestBlock("Inversion"));

    version(linalg_backend_lapack)
    {
        auto a = Matrix!(double, 3, 3)([2, 0, 0,
                                        0, 4, 0,
                                        0, 0, 8]);

        assert((cast(double[][]) (a.inverse())) ==
               [[0.5, 0, 0],
                [0, 0.25, 0],
                [0, 0, 0.125]]);
    }
}
