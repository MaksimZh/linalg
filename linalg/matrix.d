// Written in the D programming language.

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

template MatrixStorageType(T, StorageOrder storageOrder,
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

enum MatrixShape
{
    row,
    col,
    matrix
}

auto shapeForDim(size_t nrows, size_t ncols)
{
    if(nrows == 1)
        return MatrixShape.row;
    else if(ncols == 1)
        return MatrixShape.col;
    else
        return MatrixShape.matrix;
}

struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = defaultStorageOrder,
              bool canRealloc = true)
{
    alias MatrixStorageType!(T, storageOrder_, nrows_, ncols_) StorageType;
    enum auto shape = shapeForDim(nrows_, ncols_);
    enum bool isVector = shape != MatrixShape.matrix;
    enum StorageOrder storageOrder = storageOrder_;
    public // Forward type parameters
    {
        alias StorageType.ElementType ElementType;
        alias StorageType.isStatic isStatic;
    }

    /* Storage of matrix data */
    private StorageType storage;

    /* Constructors */
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
        this.storage = storage;
    }

    static if(isStatic)
    {
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
            //HACK
            auto tmp = StorageType(array);
            *cast(StorageType*)&storage =
                *cast(StorageType*)&tmp;
        }
    }
    else
    {
        static if(isVector)
        {
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
        }
        else
        {
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
        static if(shape == MatrixShape.matrix)
        {
            @property size_t nrows() pure const { return storage.nrows; }
            @property size_t ncols() pure const { return storage.ncols; }
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

        /* Test dimensions for compatibility */
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
                void setDim(size_t dim) pure
                {
                    storage.setDim(dim);
                }

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
                               nrows_ == 1 ? 1 : dynamicSize,
                               ncols_ == 1 ? 1 : dynamicSize,
                               storageOrder, false)(storage.opIndex());
            }

            ref inout auto opIndex(size_t i) pure inout
            {
                return storage[i];
            }

            ref inout auto opIndex(Slice s) pure inout
            {
                return Matrix!(ElementType,
                               nrows_ == 1 ? 1 : dynamicSize,
                               ncols_ == 1 ? 1 : dynamicSize,
                               storageOrder, false)(storage.opIndex(s));
            }
        }
        else
        {
            ref inout auto opIndex() pure inout
            {
                return Matrix!(ElementType,
                               nrows_ == 1 ? 1 : dynamicSize,
                               ncols_ == 1 ? 1 : dynamicSize,
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

    ref auto opAssign(Tsource)(auto ref const Tsource source) pure
        if(isMatrix!Tsource)
    {
        static if(!isStatic && canRealloc)
            setDim([source.nrows, source.ncols]);
        copy(source.storage, this.storage);
        return this;
    }
}

template isMatrix(T)
{
    enum bool isMatrix = isInstanceOf!(Matrix, T);
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

version(none){

unittest // Regular indices through slices
{
    debug writeln("matrix-unittest-begin");
    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(a[1][2] == 8);
    assert((a[1][2] = 80) == 80);
    assert((++a[1][2]) == 81);
    assert((a[1][2] += 3) == 84);
    debug writeln("matrix-unittest-end");
}

unittest // Slicing
{
    debug writeln("matrix-unittest-begin");
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    assert(cast(int[][]) a
           == [[0, 1, 2, 3],
               [4, 5, 6, 7],
               [8, 9, 10, 11]]);
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
    debug writeln("matrix-unittest-end");
}

unittest // Assignment for slices
{
    auto a = Matrix!(int, 3, 4)(array(iota(12)));
    auto b = Matrix!(int, 2, 2)(array(iota(12, 16)));
    debug writeln("c = a[][]");
    auto c = a[1..3][1..3];
    auto test = [[0, 1, 2, 3],
                 [4, 12, 13, 7],
                 [8, 14, 15, 11]];
    debug writeln("c = b");
    assert(cast(int[][]) (c = b) == cast(int[][]) b);
    assert(cast(int[][]) a == test);
    a[1][1] = 100;
    assert(a[1][1] == 100);
}
}
