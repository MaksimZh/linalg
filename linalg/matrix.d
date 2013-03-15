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
              StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias MatrixStorageType!(T, storageOrder_, nrows_, ncols_) StorageType;
    enum auto shape = shapeForDim(nrows_, ncols_);
    enum bool isVector = shape != MatrixShape.matrix;
    public // Forward type parameters
    {
        alias StorageType.ElementType ElementType;
        alias StorageType.isStatic isStatic;
    }

    /* Storage of matrix data */
    private StorageType storage;
    /* Forward storage parameters */
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

    /* Constructors */
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
                //HACK
                auto tmp = StorageType(array);
                *cast(StorageType*)&storage =
                    *cast(StorageType*)&tmp;
            }
        }
        else
        {
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
                //HACK
                auto tmp = StorageType(array, [nrows, ncols]);
                *cast(StorageType*)&storage =
                    *cast(StorageType*)&tmp;
            }
        }
    }

    public // Slices and indices support
    {
    }

    static if(isVector)
    {
        ElementType[] opCast() pure const
        {
            return cast(typeof(return)) storage;
        }
    }
    else
    {
        ElementType[][] opCast() pure const
        {
            return cast(typeof(return)) storage;
        }
    }
}

template isMatrix(T)
{
    enum bool isMatrix = isInstanceOf!(Matrix, T);
}

unittest // Static
{
    debug//(unittests)
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
    auto ac = Matrix!(int, 4, 1)(array(iota(4)));
    assert([ac.nrows, ac.ncols] == [4, 1]);
    assert(cast(int[]) ac == [0, 1, 2, 3]);
}

unittest // Dynamic
{
    debug//(unittests)
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
    auto bc = Matrix!(int, dynamicSize, 1)(array(iota(4)));
    assert([bc.nrows, bc.ncols] == [4, 1]);
    assert(cast(int[]) bc == [0, 1, 2, 3]);
}


version(none){
unittest // Regular indices
{
    debug(matrix)
    {
        debugOP.writeln("linalg.matrix unittest: Regular indices");
        mixin(debugIndentScope);
    }
    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(a[1, 2] == 8);
    assert((a[1, 2] = 80) == 80);
    assert(a[1, 2] == 80);
    ++a[1, 2];
    assert(a[1, 2] == 81);
    a[1, 2] += 3;
    assert(a[1, 2] == 84);
}

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

unittest // Assignment
{
    debug writeln("matrix-unittest-begin");
    debug writeln("static -> static");
    alias Matrix!(int, 3, 4) A;
    A a, b;
    debug writeln("a ", &(a.storage));
    debug writeln("a = A()");
    a = A(array(iota(12)));
    auto test = [[0, 1, 2, 3],
                 [4, 5, 6, 7],
                 [8, 9, 10, 11]];
    assert(cast(int[][])a == test);
    debug writeln("b = a");
    debug writeln(cast(int[][])(a));
    debug writeln(cast(int[][])(b = a));
    assert(cast(int[][])(b = a) == test);
    assert(cast(int[][])b == test);
    debug writeln("dynamic -> dynamic");
    alias Matrix!(int, dynamicSize, dynamicSize) A1;
    A1 a1, b1;
    debug writeln("a1 = A1()");
    a1 = A1(array(iota(12)), 3, 4);
    debug writeln("b1 = a1");
    assert(cast(int[][])(b1 = a1) == test);
    assert(cast(int[][])b1 == test);
    debug writeln("dynamic -> static");
    A c;
    debug writeln("c = a1");
    assert(cast(int[][])(c = a1) == test);
    assert(cast(int[][])c == test);
    debug writeln("static -> dynamic");
    A1 c1;
    debug writeln("c1 = a");
    assert(cast(int[][])(c1 = a) == test);
    assert(cast(int[][])c1 == test);
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
