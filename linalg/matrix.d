// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.matrix;

import std.traits;

debug import linalg.debugging;

version(unittest)
{
    import std.array;
    import std.range;
}

public import linalg.types;

import linalg.storage.regular1d;
import linalg.storage.regular2d;
import linalg.storage.slice;

import linalg.operations.basic;
import linalg.operations.conjugation;
import linalg.operations.multiplication;
import linalg.operations.eigen;


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

/**
 * Memory management of matrix or vector
 */
enum MatrixMemory
{
    stat,
    bound,
    dynamic
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
    enum MatrixMemory memoryManag =
        StorageType.isStatic ? MatrixMemory.stat : (
            isBound ? MatrixMemory.bound : MatrixMemory.dynamic);
    enum bool isStatic = (memoryManag == MatrixMemory.stat);

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
    this()(StorageType storage) pure
    {
        debug(matrix)
        {
            debugOP.writefln("Matrix<%X>.this(storage)", &this);
            mixin(debugIndentScope);
            debugOP.writefln("storage.container = <%X>, %d",
                             storage.container.ptr,
                             storage.container.length);
            debugOP.writeln("...");
            scope(exit) debug debugOP.writefln(
                "storage<%X>", &(this.storage));
            mixin(debugIndentScope);
        }
        this.storage = storage;
    }

    /**
     * If matrix is static then create a copy of the source.
     * Otherwise share the source data.
     */
    this(Tsource)(ref Tsource source) pure
        if(isMatrix!Tsource)
    {
        debug(matrix)
        {
            debugOP.writefln("Matrix<%X>.this(matrix)", &this);
            mixin(debugIndentScope);
            debugOP.writefln("matrix.storage.container = <%X>, %d",
                             source.storage.container.ptr,
                             source.storage.container.length);
            debugOP.writeln("...");
            scope(exit) debug debugOP.writefln(
                "storage<%X>", &(this.storage));
            mixin(debugIndentScope);
        }
        this = source;
    }

    static if(isStatic)
    {
        /** Create static shallow copy of array and wrap it. */
        this()(ElementType[] array) pure
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d", array.ptr, array.length);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "storage<%X>", &(this.storage));
                mixin(debugIndentScope);
            }
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
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.this()", &this);
                    mixin(debugIndentScope);
                    debugOP.writefln("array = <%X>, %d",
                                     array.ptr, array.length);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "storage<%X>", &(this.storage));
                    mixin(debugIndentScope);
                }
                this(StorageType(array));
            }

            /** Allocate new vector of given length */
            this()(size_t dim) pure
            {
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.this()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("dim = ", dim);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "storage<%X>", &(this.storage));
                    mixin(debugIndentScope);
                }
                this(StorageType(dim));
            }

            /** Allocate new vector with given dimensions */
            /* This constructor allows set vector and matrix dimensions
             * uniformly to avoid spawning shape tests.
             */
            this()(size_t nrows, size_t ncols) pure
            {
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.this()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("nrwos = ", nrows);
                    debugOP.writeln("ncols = ", ncols);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "storage<%X>", &(this.storage));
                    mixin(debugIndentScope);
                }
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
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.this()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("nrwos = ", nrows);
                    debugOP.writeln("ncols = ", ncols);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "storage<%X>", &(this.storage));
                    mixin(debugIndentScope);
                }
                this(StorageType([nrows, ncols]));
            }

            /** Wrap array with a matrix with given dimensions */
            this()(ElementType[] array,
                 size_t nrows, size_t ncols) pure
            {
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.this()", &this);
                    mixin(debugIndentScope);
                    debugOP.writefln("array = <%X>, %d",
                                     array.ptr, array.length);
                    debugOP.writeln("nrwos = ", nrows);
                    debugOP.writeln("ncols = ", ncols);
                    debugOP.writeln("...");
                    scope(exit) debug debugOP.writefln(
                        "storage<%X>", &(this.storage));
                    mixin(debugIndentScope);
                }
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

        /**
         * Whether matrix is empty (not allocated).
         * Always false for static matrix.
         */
        @property bool empty() pure
        {
            static if(isStatic)
                return false;
            else
                return nrows*ncols == 0;
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
        debug(storage)
        {
            debugOP.writefln("Matrix<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        return Matrix!(ElementType,
                       dimPattern[0] == 1 ? 1 : dynsize,
                       dimPattern[1] == 1 ? 1 : dynsize,
                       storageOrder)(this.storage.dup);
    }

    public // Operations
    {
        ref auto opAssign(Tsource)(auto ref Tsource source) pure
            if(isMatrix!Tsource)
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opAssign()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("source = <%X>", &source);
                debugOP.writeln("...");
                scope(exit) debug debugOP.writefln(
                    "storage<%X>", &(this.storage));
                mixin(debugIndentScope);
            }
            static if(memoryManag == MatrixMemory.dynamic)
                this.storage = typeof(this.storage)(source.storage);
            else
                if(source.empty)
                    fill(zero!(Tsource.ElementType), this.storage);
                else
                    copy(source.storage, this.storage);
            return this;
        }

        /* Unary operations
         */

        ref auto opUnary(string op)() pure
            if(op == "+")
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opUnary("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            return this;
        }

        ref auto opUnary(string op)() pure
            if(op == "-")
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opUnary("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            static if(memoryManag == MatrixMemory.stat)
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
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opOpAssign("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("source = <%X>", &source);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            /*
             * If matrix is empty (not allocated) then just assume it has
             * appropriate size and filled with zeros.
             */
            static if(memoryManag == MatrixMemory.dynamic)
                if(empty)
                {
                    this.setDim([source.nrows, source.ncols]);
                    static if(Tsource.memoryManag == MatrixMemory.dynamic)
                        if(source.empty)
                            return this;
                    linalg.operations.basic.map!(op ~ "a")(
                        source.storage, this.storage);
                    return this;
                }
            static if(Tsource.memoryManag == MatrixMemory.dynamic)
                if(source.empty)
                    return this;
            linalg.operations.basic.zip!("a"~op~"b")(
                this.storage, source.storage, this.storage);
            return this;
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(isMatrix!Trhs && (op == "+" || op == "-"))
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opBinary("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("rhs = <%X>", &rhs);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            /*
             * If one of the operands is empty (not allocated) then
             * return copy the other one with proper sign if it has proper type.
             *
             * Copy is needed since the result of binary operation
             * is not expected to share memory with one of the operands.
             */
            alias TypeOfResultMatrix!(typeof(this), op, Trhs) Tresult;
            // Left operand can be empty and right operand is of result type
            static if(memoryManag == MatrixMemory.dynamic
                      && is(Tresult == Trhs))
                if(empty)
                    return mixin(op~"rhs").dup;
            // Right operand can be empty and left operand is of result type
            static if(Trhs.memoryManag == MatrixMemory.dynamic
                      && is(Tresult == typeof(this)))
                if(rhs.empty)
                    return this.dup;
            // Result can not be copy of any of the operands
            Tresult dest;
            // Allocate memory for dynamic matrix
            static if(Tresult.memoryManag == MatrixMemory.dynamic)
                dest.setDim([this.nrows, this.ncols]);
            // Calculate the result
            if(this.empty)
                linalg.operations.basic.map!((a, lhs) => mixin("lhs"~op~"a"))(
                    rhs.storage, dest.storage, zero!ElementType);
            else if(rhs.empty)
                linalg.operations.basic.map!((a, rhs) => mixin("a"~op~"rhs"))(
                    this.storage, dest.storage, zero!(Trhs.ElementType));
            else
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
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opOpAssign("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("source = ", source);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            static if(memoryManag == MatrixMemory.dynamic)
                if(empty)
                    return this;
            linalg.operations.basic.map!((a, b) => mixin("a"~op~"b"))(
                this.storage, this.storage, source);
            return this;
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(!(isMatrix!Trhs) && (op == "*" || op == "/"))
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opBinary("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("rhs = <%X>", &rhs);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
            static if(typeof(dest).memoryManag == MatrixMemory.dynamic)
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
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opBinaryRight("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("lhs = <%X>", &lhs);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            TypeOfResultMatrix!(Tlhs, op, typeof(this)) dest;
            static if(typeof(dest).memoryManag == MatrixMemory.dynamic)
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
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opOpAssign("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("source = <%X>", &source);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }
            return (this = this * source);
        }

        auto opBinary(string op, Trhs)(
            auto ref Trhs rhs) pure
            if(isMatrix!Trhs && op == "*")
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.opBinary("~op~")", &this);
                mixin(debugIndentScope);
                debugOP.writefln("rhs = <%X>", &rhs);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            static if(this.shape == MatrixShape.row
                      && rhs.shape == MatrixShape.col)
            {
                return mulAsMatrices(this.storage, rhs.storage);
            }
            else
            {
                TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
                static if(typeof(dest).memoryManag == MatrixMemory.dynamic)
                    dest.setDim([this.nrows, rhs.ncols]);
                mulAsMatrices(this.storage, rhs.storage, dest.storage);
                return dest;
            }
        }
    }

    public // Diagonalization
    {
        static if(!isVector)
        {
            /**
             * Return all eigenvalues.
             *
             * Only upper-triangle part is used.
             * Contents of matrix will be modified.
             */
            auto symmEigenval()() pure
            {
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.symmEigenval()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    mixin(debugIndentScope);
                }

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
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.symmEigenval()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    mixin(debugIndentScope);
                }

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
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.symmEigenAll()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    mixin(debugIndentScope);
                }

                return matrixSymmEigenAll(this.storage, ilo, iup);
            }
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
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.conj()", &this);
                mixin(debugIndentScope);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            Matrix!(ElementType, dimPattern[1], dimPattern[0], storageOrder) dest;
            static if(typeof(dest).memoryManag == MatrixMemory.dynamic)
                dest.setDim([this.ncols, this.nrows]);
            conjMatrix(this.storage, dest.storage);
            return dest;
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
                return storage.byRow!(MatrixView!(ElementType, 1, dynsize,
                                                  storageOrder))();
            }

            @property auto byCol() pure
            {
                return storage.byCol!(MatrixView!(ElementType, dynsize, 1,
                                                  storageOrder))();
            }

            @property auto byBlock(size_t[2] subdim) pure
            {
                return storage.byBlock!(MatrixView!(ElementType,
                                                    dynsize, dynsize,
                                                    storageOrder))(subdim);
            }
        }
    }
}

/** Detect whether $(D T) is matrix */
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
                       Tlhs.dimPattern[0] == 1 ? 1 : dynsize,
                       Tlhs.dimPattern[1] == 1 ? 1 : dynsize,
                       Tlhs.storageOrder) TypeOfResultMatrix;
    else static if(isMatrix!Trhs && (op == "*"))
         alias Matrix!(TypeOfOp!(Tlhs, op, Trhs.ElementType),
                       Trhs.dimPattern[0] == 1 ? 1 : dynsize,
                       Trhs.dimPattern[1] == 1 ? 1 : dynsize,
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
         auto ref Targs args) pure
        if(isMatrix!Tsource)
    {
        Matrix!(typeof(fun(source[0, 0], args)),
                Tsource.dimPattern[0], Tsource.dimPattern[1],
                Tsource.storageOrder) dest;
        /* If source is empty then return empty matrix */
        static if(!(Tsource.isStatic))
            if(source.empty)
                return dest;
        static if(!(typeof(dest).isStatic))
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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Constructors & cast");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
        debug writeln(cast(int[][]) mb);
        assert(cast(int[][]) mb
               == [[1, 2, 3],
                   [4, 5, 6]]);
    }
}

unittest // Storage direct access
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Storage direct access");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = Matrix!(int, dynsize, dynsize, StorageOrder.row)(src, 2, 3);
    assert(a.storage.container.ptr == src.ptr);
    assert(a.storage.container == [1, 2, 3, 4, 5, 6]);
    assert(a.storage.dim == [2, 3]);
    assert(a.storage.stride == [3, 1]);
}

unittest // Dimension control
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Dimension control");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    Matrix!(int, dynsize, dynsize) a;
    assert(a.empty);
    assert(a.nrows == 0);
    assert(a.ncols == 0);
    assert(a.dim == [0, 0]);
    a.setDim([2, 3]);
    assert(!(a.empty));
    assert(a.nrows == 2);
    assert(a.ncols == 3);
    assert(a.dim == [2, 3]);
    assert(a.isCompatDim([22, 33]));

    Matrix!(int, 2, 3) b;
    assert(!(b.empty));
    assert(b.nrows == 2);
    assert(b.ncols == 3);
    assert(b.dim == [2, 3]);
    assert(!(b.isCompatDim([22, 33])));
}

unittest // Copying
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Copying");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Regular indices");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Slices");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto a = Matrix!(int, 4, 6)(array(iota(24)));
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
    assert(cast(int[][]) a
           == [[0, 1, 2, 3, 4, 5],
               [6, 101, 8, 9, 102, 11],
               [12, 13, 14, 15, 16, 17],
               [18, 103, 20, 21, 104, 23]]);
}

unittest // Unary + and -
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Unary + and -");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix += and -=");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [7, 8, 9, 10, 11, 12];
    /*NOTE
     * One has to use src1.dup even if a is static.
     * Will be resolved when mutable matrices referring
     * immutable data are implemented.
     */
    {
        auto a = Matrix!(int, 2, 3)(src1.dup);
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
        auto a = Matrix!(int, 2, 3)(src1.dup);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 3);
        a += b;
        assert(cast(int[][]) a == [[8, 10, 12],
                                   [14, 16, 18]]);
        a -= b;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src1.dup, 2, 3);
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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix + and -");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix *= scalar");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src = [1, 2, 3, 4, 5, 6];
    /*NOTE
     * One has to use src.dup even if a is static.
     * Will be resolved when mutable matrices referring
     * immutable data are implemented.
     */
    {
        auto a = Matrix!(int, 2, 3)(src.dup);
        a *= 2;
        assert(cast(int[][]) a == [[2, 4, 6],
                                   [8, 10, 12]]);
        a /= 2;
        assert(cast(int[][]) a == [[1, 2, 3],
                                   [4, 5, 6]]);
    }
    {
        auto a = Matrix!(int, dynsize, dynsize)(src.dup, 2, 3);
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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix * scalar");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix *=");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    /*NOTE
     * One has to use src1.dup even if a is static.
     * Will be resolved when mutable matrices referring
     * immutable data are implemented.
     */
    {
        int[] src1 = [1, 2, 3, 4];
        int[] src2 = [7, 8, 9, 10];
        auto a = Matrix!(int, 2, 2)(src1.dup);
        auto b = Matrix!(int, 2, 2)(src2);
        a *= b;
        assert(cast(int[][]) a == [[25, 28],
                                   [57, 64]]);
    }
    {
        int[] src1 = [1, 2, 3, 4, 5, 6];
        int[] src2 = [7, 8, 9, 10, 11, 12];
        auto a = Matrix!(int, dynsize, dynsize)(src1.dup, 2, 3);
        auto b = Matrix!(int, 3, 2)(src2);
        a *= b;
        assert(cast(int[][]) a == [[58, 64],
                                   [139, 154]]);
    }
    {
        int[] src1 = [1, 2, 3, 4];
        int[] src2 = [7, 8, 9, 10];
        auto a = Matrix!(int, 2, 2)(src1.dup);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 2, 2);
        a *= b;
        assert(cast(int[][]) a == [[25, 28],
                                   [57, 64]]);
    }
    {
        int[] src1 = [1, 2, 3, 4, 5, 6];
        int[] src2 = [7, 8, 9, 10, 11, 12];
        auto a = Matrix!(int, dynsize, dynsize)(src1.dup, 2, 3);
        auto b = Matrix!(int, dynsize, dynsize)(src2, 3, 2);
        a *= b;
        assert(cast(int[][]) a == [[58, 64],
                                   [139, 154]]);
    }
}

unittest // Matrix *
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix *");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [7, 8, 9, 10, 11, 12];
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
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Ranges");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

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

version(all) // Old unittests
{
    unittest // Diagonalization
    {
        debug(unittests)
        {
            debugOP.writeln("linalg.matrix unittest: Diagonalization");
            mixin(debugIndentScope);
        }
        else debug mixin(debugSilentScope);

        version(linalg_backend_lapack)
        {
            alias Complex!double C;
            auto a = Matrix!(C, 3, 3)(
                [C(1, 0), C(0, 0), C(0, 0),
                 C(0, 0), C(2, 0), C(0, 0),
                 C(0, 0), C(0, 0), C(3, 0)]);
            double[] val;
            auto b = a.dup;
            //FIXME: may fail for low precision
            assert(a.symmEigenval() == [1, 2, 3]);
            assert(b.symmEigenval(1, 2) == [2, 3]);
        }
    }

    unittest // Map function
    {
        debug(unittests)
        {
            debugOP.writeln("linalg.matrix unittest: Map function");
            mixin(debugIndentScope);
        }
        else debug mixin(debugSilentScope);

        int b = 2;
        /*NOTE:
         * One has to specify type of a.
         * Otherwise type of destination container will be const somehow.
         */
        assert(cast(int[][]) map!((int a, b) => a*b)(
                   Matrix!(int, 3, 4)(array(iota(12))), b)
               == [[0, 2, 4, 6],
                   [8, 10, 12, 14],
                   [16, 18, 20, 22]]);
    }

    unittest // Hermitian conjugation
    {
        debug(unittests)
        {
            debugOP.writeln("linalg.matrix unittest: Hermitian conjugation");
            mixin(debugIndentScope);
        }
        else debug mixin(debugSilentScope);

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
}
