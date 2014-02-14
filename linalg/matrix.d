// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.matrix;

public import linalg.aux.types;

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
import linalg.aux.opmixins;

debug import linalg.aux.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

alias linalg.storage.slice.Slice Slice; //NOTE: waiting for proper slice support


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
            @property size_t nrows() pure { return storage.nrows; }
            @property size_t ncols() pure { return storage.ncols; } //ditto
        }
        else static if(shape == MatrixShape.row)
        {
            enum size_t nrows = 1;
            @property size_t ncols() pure { return storage.length; }
        }
        else static if(shape == MatrixShape.col)
        {
            @property size_t nrows() pure { return storage.length; }
            enum size_t ncols = 1;
        }
        else static assert(false);
        /** Dimensions of matrix */
        @property size_t[2] dim() pure { return [nrows, ncols]; }

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
        //NOTE: depends on DMD pull-request 443
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
        version(all)
        {
            mixin template InjectOpAssign()
            {
                ref auto opOpAssign(string op, Tsource)(
                    auto ref Tsource source) pure
                    if(isMatrix!Tsource && (op == "+" || op == "-"))
                    { return this; }
            }

            mixin InjectOpAssign;
        }
        version(none)
        {
            ref auto opOpAssign(string op, Tsource)(
                auto ref Tsource source) pure
                if(isMatrix!Tsource && (op == "+" || op == "-"))
                { return this; }
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

unittest // Matrix += and -=
{
    Matrix!(int, 2, 3) a, b;
    a += b;
}
