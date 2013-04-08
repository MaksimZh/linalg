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
import linalg.storage.operations;

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
private auto shapeForDim(size_t nrows, size_t ncols)
{
    if(nrows == 1)
        return MatrixShape.row;
    else if(ncols == 1)
        return MatrixShape.col;
    else
        return MatrixShape.matrix;
}

/**
 * Matrix or vector.
 */
struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = defaultStorageOrder,
              bool canRealloc = true)
{
    /** Dimensions patterns */
    enum size_t nrowsPat = nrows_;
    enum size_t ncolsPat = ncols_; ///ditto

    /* Select storage type.
     * Note: vectors use 1d storage (mainly for optimization)
     */
    alias MatrixStorageType!(T, storageOrder_, nrowsPat, ncolsPat) StorageType;

    /** Shape of the matrix or vector */
    enum auto shape = shapeForDim(nrowsPat, ncolsPat);
    /** Whether this is vector */
    enum bool isVector = shape != MatrixShape.matrix;
    /** Storage order */
    enum StorageOrder storageOrder = storageOrder_;
    public // Forward type parameters
    {
        /** Type of matrix elements */
        alias StorageType.ElementType ElementType;
        /** Whether wraps static array or use dynamic allocation */
        alias StorageType.isStatic isStatic;
    }

    /* Storage of matrix data */
    private StorageType storage;

    /* Constructors
     */

    /* Creates matrix for storage. For internal use only. */
    private inout this(inout StorageType storage) pure
    {
        debug(matrix)
        {
            debugOP.writefln("Matrix<%X>.this()", &this);
            mixin(debugIndentScope);
            debugOP.writefln("storage.data = <%X>, %d",
                             storage.data.ptr,
                             storage.data.length);
            debugOP.writeln("...");
            scope(exit) debug debugOP.writefln(
                "storage<%X>", &(this.storage));
            mixin(debugIndentScope);
        }
        //HACK: workaround for DMD issue 9665
        *cast(StorageType*)&(this.storage) =
            *cast(StorageType*)&storage;
    }

    static if(isStatic)
    {
        /** Create static shallow copy of array and wrap it. */
        inout this(inout ElementType[] array) pure
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
            //HACK: workaround for DMD issue 9665
            auto tmp = StorageType(array);
            *cast(StorageType*)&storage =
                *cast(StorageType*)&tmp;
        }
    }
    else
    {
        static if(isVector)
        {
            /** Create vector wrapping array */
            inout this(inout ElementType[] array) pure
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
            this(size_t dim) pure
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
            this(size_t nrows, size_t ncols) pure
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
            this(size_t nrows, size_t ncols) pure
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
            inout this(inout ElementType[] array,
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

        /** Test dimensions for compatibility */
        bool isCompatDim(in size_t[] dim) pure
        {
            static if(shape == MatrixShape.matrix)
                return storage.isCompatDim(dim);
            else static if(shape == MatrixShape.row)
                return dim[0] == 1 && storage.isCompatDim(dim[1]);
            else static if(shape == MatrixShape.col)
                return dim[1] == 1 && storage.isCompatDim(dim[0]);
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

        size_t opDollar(size_t dimIndex)() pure const
        {
            return storage.opDollar!dimIndex;
        }

        static if(isVector)
        {
            ref inout auto opIndex() pure inout
            {
                return Matrix!(ElementType,
                               nrowsPat == 1 ? 1 : dynamicSize,
                               ncolsPat == 1 ? 1 : dynamicSize,
                               storageOrder, false)(storage.opIndex());
            }

            ref inout auto opIndex(size_t i) pure inout
            {
                return storage[i];
            }

            ref inout auto opIndex(Slice s) pure inout
            {
                return Matrix!(ElementType,
                               nrowsPat == 1 ? 1 : dynamicSize,
                               ncolsPat == 1 ? 1 : dynamicSize,
                               storageOrder, false)(storage.opIndex(s));
            }
        }
        else
        {
            ref inout auto opIndex() pure inout
            {
                return Matrix!(ElementType,
                               nrowsPat == 1 ? 1 : dynamicSize,
                               ncolsPat == 1 ? 1 : dynamicSize,
                               storageOrder, false)(storage.opIndex());
            }

            ref inout auto opIndex(size_t irow, size_t icol) pure inout
            {
                return storage[irow, icol];
            }

            ref inout auto opIndex(Slice srow, size_t icol) pure inout
            {
                return Matrix!(ElementType,
                               dynamicSize, 1,
                               storageOrder, false)(
                    storage.opIndex(srow, icol));
            }

            ref inout auto opIndex(size_t irow, Slice scol) pure inout
            {
                return Matrix!(ElementType,
                               1, dynamicSize,
                               storageOrder, false)(
                    storage.opIndex(irow, scol));
            }

            ref inout auto opIndex(Slice srow, Slice scol) pure inout
            {
                return Matrix!(ElementType,
                               dynamicSize, dynamicSize,
                               storageOrder, false)(
                    storage.opIndex(srow, scol));
            }
        }
    }

    /* Cast to built-in array */
    static if(isVector)
    {
        auto opCast(Tcast)() pure const
            if(is(Tcast == ElementType[]))
        {
            return cast(Tcast) storage;
        }

        auto opCast(Tcast)() pure const
            if(is(Tcast == ElementType[][]))
        {
            return cast(Tcast)
                StorageRegular2D!(ElementType,
                                  shape == MatrixShape.row
                                  ? StorageOrder.rowMajor
                                  : StorageOrder.colMajor,
                                  dynamicSize, dynamicSize)(storage);
        }
    }
    else
    {
        ElementType[][] opCast() pure const
        {
            return cast(typeof(return)) storage;
        }
    }

    /** Create shallow copy of matrix */
    @property auto dup() pure const
    {
        debug(storage)
        {
            debugOP.writefln("Matrix<%X>.dup()", &this);
            mixin(debugIndentScope);
            debugOP.writeln("...");
            mixin(debugIndentScope);
        }
        return Matrix!(ElementType,
                       nrowsPat, ncolsPat,
                       storageOrder, true)(this.storage.dup);
    }

    public // Operations
    {
        static if(isStatic)
            ref auto opAssign(Tsource)(auto ref const Tsource source) pure
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
                copy(source.storage, this.storage);
                return this;
            }
        else
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
                static if(!isStatic && canRealloc)
                    this.storage = typeof(this.storage)(source.storage);
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
            static if(isStatic)
                Matrix dest;
            else
                auto dest = Matrix!(ElementType,
                                    nrowsPat, ncolsPat,
                                    storageOrder)(nrows, ncols);
            linalg.storage.operations.map!("-a")(this.storage, dest.storage);
            return dest;
        }

        /* Matrix addition and subtraction
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref const Tsource source) pure
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
            linalg.storage.operations.zip!("a"~op~"b")(
                this.storage, source.storage, this.storage);
            return this;
        }

        ref auto opBinary(string op, Trhs)(
            auto ref const Trhs rhs) pure
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
            TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
            static if(!(typeof(dest).isStatic))
                dest.setDim([this.nrows, this.ncols]);
            linalg.storage.operations.zip!("a"~op~"b")(
                this.storage, source.storage, dest.storage);
            return dest;
        }

        /* Multiplication by scalar
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref const Tsource source) pure
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
            linalg.storage.operations.map!(
                (ElementType a) => mixin("a"~op~"source"))(
                    this.storage, this.storage);
            return this;
        }

        ref auto opBinary(string op, Trhs)(
            auto ref const Trhs rhs) pure
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
            static if(!(typeof(dest).isStatic))
                dest.setDim([this.nrows, this.ncols]);
            linalg.storage.operations.map!(
                (ElementType a) => mixin("a"~op~"rhs"))(
                    this.storage, dest.storage);
            return dest;
        }

        /* Multiplication between matrix elements and scalar
         * can be non-commutative
         */
        ref auto opBinaryRight(string op, Tlhs)(
            auto ref const Tlhs lhs) pure
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
            TypeOfResultMatrix!(typeof(this), op, Tlhs) dest;
            static if(!(typeof(dest).isStatic))
                dest.setDim([this.nrows, this.ncols]);
            linalg.storage.operations.map!(
                (ElementType a) => mixin("lhs"~op~"a"))(
                    this.storage, dest.storage);
            return dest;
        }

        /* Matrix multiplication
         */

        ref auto opOpAssign(string op, Tsource)(
            auto ref const Tsource source) pure
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

        ref auto opBinary(string op, Trhs)(
            auto ref const Trhs rhs) pure
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
                return linalg.storage.operations.mulAsMatrices(
                    this.storage, rhs.storage);
            }
            else
            {
                TypeOfResultMatrix!(typeof(this), op, Trhs) dest;
                static if(!(typeof(dest).isStatic))
                    dest.setDim([this.nrows, rhs.ncols]);
                linalg.storage.operations.mulAsMatrices(
                    this.storage, rhs.storage, dest.storage);
                return dest;
            }
        }
    }

    /** Return dynamic array referring matrix elements */
    @property auto data() pure inout
    {
        return storage.data;
    }

    public // Diagonalization
    {
        static if(!isVector)
        {
            /**
             * Return eigenvalues in given range
             * (ascending order, starts from 0, includes borders).
             *
             * Only upper-triangle part is used.
             * Contents of matrix will be changed.
             */
            double[] symmEigenval()(size_t ilo, size_t iup) pure
            {
                debug(matrix)
                {
                    debugOP.writefln("Matrix<%X>.symmEigenval()", &this);
                    mixin(debugIndentScope);
                    debugOP.writeln("...");
                    mixin(debugIndentScope);
                }

                return linalg.storage.operations.matrixSymmEigenval(
                    this.storage, ilo, iup);
            }
        }
    }

    public // Other operations
    {
        /**
         * Map function over matrix.
         */
        ref auto map(alias fun)() pure const
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.map()", &this);
                mixin(debugIndentScope);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            Matrix!(ReturnTypeOfUnaryFun!(fun, ElementType),
                    nrowsPat, ncolsPat, storageOrder) dest;
            static if(!(typeof(dest).isStatic))
                dest.setDim([this.nrows, this.ncols]);
            linalg.storage.operations.map!(fun)(this.storage, dest.storage);
            return dest;
        }

        /**
         * Return transposed matrix for real matrix or
         * conjugated and transposed matrix for complex matrix.
         */
        ref auto conj() pure const
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.conj()", &this);
                mixin(debugIndentScope);
                debugOP.writeln("...");
                mixin(debugIndentScope);
            }

            Matrix!(ElementType, ncolsPat, nrowsPat, storageOrder) dest;
            static if(!(typeof(dest).isStatic))
                dest.setDim([this.ncols, this.nrows]);
            static if(isVector) {}
            else
                linalg.storage.operations.conjMatrix(
                    this.storage, dest.storage);
            return dest;
        }
    }
}

/** Detect whether $(D T) is matrix */
template isMatrix(T)
{
    enum bool isMatrix = isInstanceOf!(Matrix, T);
}

/* Derive result type for matrix operations */
private template TypeOfResultMatrix(Tlhs, string op, Trhs)
{
    static if(isMatrix!Tlhs && isMatrix!Trhs)
        static if(op == "+" || op == "-")
            alias Matrix!(TypeOfOp!(Tlhs.ElementType,
                                    op, Trhs.ElementType),
                          Tlhs.nrowsPat, Tlhs.ncolsPat,
                          Tlhs.storageOrder) TypeOfResultMatrix;
        else static if(op == "*")
            alias Matrix!(TypeOfOp!(Tlhs.ElementType,
                                    op, Trhs.ElementType),
                          Tlhs.nrowsPat, Trhs.ncolsPat,
                          Tlhs.storageOrder) TypeOfResultMatrix;
    else static if(isMatrix!Tlhs && (op == "*" || op == "/"))
         alias Matrix!(TypeOfOp!(Tlhs.ElementType, op, Trhs),
                       Tlhs.nrowsPat, Tlhs.ncolsPat,
                       Tlhs.storageOrder) TypeOfResultMatrix;
    else static if(isMatrix!Trhs && (op == "*"))
         alias Matrix!(TypeOfOp!(Tlhs, op, Trhs.ElementType),
                       Trhs.nrowsPat, Trhs.ncolsPat,
                       Trhs.storageOrder) TypeOfResultMatrix;
    else
        alias void TypeOfResultMatrix;
}

unittest // Static
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Static");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    assert([a.nrows, a.ncols] == [3, 4]);
    assert(cast(int[][]) a == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    auto ar = Matrix!(int, 1, 3)(array(iota(3)));
    assert([ar.nrows, ar.ncols] == [1, 3]);
    assert(cast(int[]) ar == [0, 1, 2]);
    assert(cast(int[][]) ar == [[0, 1, 2]]);
    auto ac = Matrix!(int, 4, 1)(array(iota(4)));
    assert([ac.nrows, ac.ncols] == [4, 1]);
    assert(cast(int[]) ac == [0, 1, 2, 3]);
    assert(cast(int[][]) ac == [[0],
                                [1],
                                [2],
                                [3]]);
}

unittest // Dynamic
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Dynamic");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    auto b = Matrix!(int, dynamicSize, dynamicSize)(array(iota(12)), 3, 4);
    assert([b.nrows, b.ncols] == [3, 4]);
    assert(cast(int[][]) b == [[0, 1, 2, 3],
                               [4, 5, 6, 7],
                               [8, 9, 10, 11]]);
    auto br = Matrix!(int, 1, dynamicSize)(array(iota(3)));
    assert([br.nrows, br.ncols] == [1, 3]);
    assert(cast(int[]) br == [0, 1, 2]);
    assert(cast(int[][]) br == [[0, 1, 2]]);
    auto bc = Matrix!(int, dynamicSize, 1)(array(iota(4)));
    assert([bc.nrows, bc.ncols] == [4, 1]);
    assert(cast(int[]) bc == [0, 1, 2, 3]);
    assert(cast(int[][]) bc == [[0],
                                [1],
                                [2],
                                [3]]);
}

unittest // Assignment
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Assignment");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    debug debugOP.writeln("static -> static");
    alias Matrix!(int, 3, 4) A;
    A a, b;
    a = A(array(iota(12)));
    auto test = [[0, 1, 2, 3],
                 [4, 5, 6, 7],
                 [8, 9, 10, 11]];
    assert(cast(int[][])a == test);
    assert(cast(int[][])(b = a) == test);
    assert(cast(int[][])b == test);
    debug debugOP.writeln("dynamic -> dynamic");
    alias Matrix!(int, dynamicSize, dynamicSize) A1;
    A1 a1, b1;
    a1 = A1(array(iota(12)), 3, 4);
    assert(cast(int[][])(b1 = a1) == test);
    assert(cast(int[][])b1 == test);
    debug debugOP.writeln("dynamic -> static");
    A c;
    assert(cast(int[][])(c = a1) == test);
    assert(cast(int[][])c == test);
    debug debugOP.writeln("static -> dynamic");
    A1 c1;
    assert(cast(int[][])(c1 = a) == test);
    assert(cast(int[][])c1 == test);
}

unittest // opOpAssign
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: opOpAssign");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    alias Matrix!(int, 3, 4) A;
    A a, b;
    a = A(array(iota(12)));
    b = A(array(iota(12, 24)));
    a += b;
    assert(cast(int[][]) a == [[12, 14, 16, 18],
                               [20, 22, 24, 26],
                               [28, 30, 32, 34]]);

    a = A(array(iota(12)));
    a *= 2;
    assert(cast(int[][]) a == [[0, 2, 4, 6],
                               [8, 10, 12, 14],
                               [16, 18, 20, 22]]);
}

unittest // opUnary
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: opUnary");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    alias Matrix!(int, 3, 4) A;
    A a;
    a = A(array(iota(12)));
    assert(cast(int[][]) (+a) == [[0, 1, 2, 3],
                                  [4, 5, 6, 7],
                                  [8, 9, 10, 11]]);
    assert(cast(int[][]) (-a) == [[-0, -1, -2, -3],
                                  [-4, -5, -6, -7],
                                  [-8, -9, -10, -11]]);
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

unittest // Matrix multiplication
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Matrix multiplication");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    {
        auto a = Matrix!(int, 1, 3)([1, 2, 3]);
        auto b = Matrix!(int, 3, 1)([4, 5, 6]);
        assert(a * b == 32);
    }
    {
        auto a = Matrix!(int, 1, 3)([1, 2, 3]);
        auto b = Matrix!(int, 3, 2)([6, 7, 8, 9, 10, 11]);
        assert(cast(int[][]) (a * b) == [[52, 58]]);
    }
    {
        auto a = Matrix!(int, 2, 3)([1, 2, 3, 4, 5, 6]);
        auto b = Matrix!(int, 3, 1)([6, 7, 8]);
        assert(cast(int[][]) (a * b) == [[44],
                                         [107]]);
    }
    {
        auto a = Matrix!(int, 2, 3)([1, 2, 3, 4, 5, 6]);
        auto b = Matrix!(int, 3, 2)([6, 7, 8, 9, 10, 11]);
        assert(cast(int[][]) (a * b) == [[52, 58],
                                         [124, 139]]);
    }
    {
        auto a = Matrix!(int, 0, 0)([1, 2, 3, 4, 5, 6], 2, 3);
        auto b = Matrix!(int, 3, 2)([6, 7, 8, 9, 10, 11]);
        a *= b;
        assert(cast(int[][]) a == [[52, 58],
                                   [124, 139]]);
    }
}

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
        //FIXME: may fail for low precision
        assert(a.symmEigenval(1, 2) == [2, 3]);
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

    assert(cast(int[][]) (Matrix!(int, 3, 4)(array(iota(12))).map!("a*2")())
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
}
