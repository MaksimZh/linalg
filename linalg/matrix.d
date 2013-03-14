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

import linalg.storage.regular2d;

struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias StorageRegular2D!(T, storageOrder_, nrows_, ncols_) StorageType;
    public // Forward type parameters
    {
        alias StorageType.ElementType ElementType;
        alias StorageType.isStatic isStatic;
    }

    /* Storage of matrix data */
    private StorageType storage;
    public // Forward storage parameters
    {
        @property size_t nrows() pure const { return storage.nrows; }
        @property size_t ncols() pure const { return storage.ncols; }
    }

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
        inout this(inout ElementType[] array, size_t nrows, size_t ncols) pure
        {
            debug(matrix)
            {
                debugOP.writefln("Matrix<%X>.this()", &this);
                mixin(debugIndentScope);
                debugOP.writefln("array = <%X>, %d", array.ptr, array.length);
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

    public // Slices and indices support
    {
        auto opSlice(size_t dimIndex)(size_t lo, size_t up) pure const
        {
            return storage.opSlice!(dimIndex)(lo, up);
        }

        auto opDollar(size_t dimIndex)() pure const
        {
            return storage.opDollar!(dimIndex);
        }

        ref inout auto opIndex(size_t irow, size_t icol) pure inout
        {
            return storage.opIndex(irow, icol);
        }
    }

    ElementType[][] opCast() pure const
    {
        return cast(typeof(return)) storage;
    }
}

template isMatrix(T)
{
    enum bool isMatrix = isInstanceOf!(Matrix, T);
}

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
