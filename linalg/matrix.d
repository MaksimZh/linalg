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

import linalg.storage.dense2d;
import linalg.storage.slice;

struct Matrix(T, size_t nrows_, size_t ncols_,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    alias StorageDense2D!(T, storageOrder_, nrows_, ncols_) StorageType;
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
                indent.writefln("Matrix<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d", array.ptr, array.length);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("storage<%X>", &(this.storage));
                        indent.rem();
                    }
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
                indent.writefln("Matrix<%X>.this()", &this);
                indent.add();
                indent.writefln("array = <%X>, %d", array.ptr, array.length);
                indent.writeln("nrwos = ", nrows);
                indent.writeln("ncols = ", ncols);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.writefln("storage<%X>", &(this.storage));
                        indent.rem();
                    }
            }
            //HACK
            auto tmp = StorageType(array, [nrows, ncols]);
            *cast(StorageType*)&storage =
                *cast(StorageType*)&tmp;
        }
    }

    public // Regular indices interface
    {
        //TODO: make assignment accept any suitable type

        ref const(ElementType) opIndex(size_t irow, size_t icol) pure const
        {
            return storage.readElement(irow, icol);
        }

        ref ElementType opIndexAssign(ElementType rhs,
                                      size_t irow, size_t icol) pure
        {
            storage.takeElement(irow, icol) = rhs; //DMD: Not lvalue???
            return storage.takeElement(irow, icol);
        }

        ref ElementType opIndexUnary(string op)(size_t irow, size_t icol) pure
        {
            return mixin(op ~ "(storage.takeElement(irow, icol))");
        }

        ref ElementType opIndexOpAssign(string op)(ElementType rhs,
                                                   size_t irow,
                                                   size_t icol) pure
        {
            return mixin("storage.takeElement(irow, icol) " ~ op ~ "= rhs");
        }
    }

    public // Slice interface
    {
        auto opSlice()
        {
            return SliceProxy!false(&this, SliceBounds(0, nrows));
        }

        auto opSlice(size_t lo, size_t up)
        {
            return SliceProxy!false(&this, SliceBounds(lo, up));
        }

        auto opIndex(size_t i)
        {
            return SliceProxy!true(&this, SliceBounds(i));
        }

        struct SliceProxy(bool isIndex)
        {
            const SliceBounds bounds;

            Matrix* pSource; // Pointer to the matrix being sliced

            private this(Matrix* pSource_, in SliceBounds bounds_)
            {
                pSource = pSource_;
                bounds = bounds_;
            }

            static if(isIndex)
            {
                ref const(ElementType) opIndex(size_t i) pure const
                {
                    return (*pSource)[bounds.lo, i];
                }

                ref ElementType opIndexAssign(ElementType rhs,
                                              size_t i) pure
                {
                    return (*pSource)[bounds.lo, i] = rhs;
                }

                ref ElementType opIndexUnary(string op)(size_t i) pure
                {
                    return mixin(op ~ "((*pSource)[bounds.lo, i])");
                }

                ref ElementType opIndexOpAssign(string op)(ElementType rhs,
                                                           size_t i) pure
                {
                    return mixin(
                        "(*pSource)[bounds.lo, i] " ~ op ~ "= rhs");
                }
            }
            else
            {
                ref inout auto opIndex(size_t i) pure inout
                {
                    return MatrixView!(StorageType, false, true)(
                        pSource.storage.slice(bounds, SliceBounds(i)));
                }
            }

            ref inout auto opSlice() pure inout
            {
                return MatrixView!(StorageType, isIndex, false)(
                    pSource.storage.slice(
                        bounds, SliceBounds(0, pSource.ncols)));
            }

            ref inout auto opSlice(size_t lo, size_t up) pure inout
            {
                return MatrixView!(StorageType, isIndex, false)(
                    pSource.storage.slice(bounds, SliceBounds(lo, up)));
            }
        }
    }

    public // Assignment
    {
        ref auto opAssign(Tsource)(auto ref Tsource source)
            if(isMatrixOrView!Tsource)
        {
            debug(matrix)
            {
                indent.writefln("Matrix<%X>.opAssign()", &this);
                indent.add();
                indent.writefln("source<%X>", &source);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.rem();
                    }
            }
            linalg.storage.operations.copy(source.storage, this.storage);
            return this;
        }
    }

    ElementType[][] opCast() pure const
    {
        return cast(typeof(return)) storage;
    }
}

struct MatrixView(SourceStorageType, bool oneRow, bool oneCol)
{
    alias ViewDense2D!(SourceStorageType) StorageType;
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

    /* Constructor */
    inout this(inout StorageType storage) pure
    {
        debug(matrix)
        {
            indent.writefln("MatrixView<%X>.this()", &this);
            indent.add();
            indent.writeln("...");
            indent.add();
            scope(exit)
                debug
                {
                    indent.rem();
                    indent.rem();
                }
        }
        this.storage = storage;
    }

    public // Assignment
    {
        auto opAssign(Tsource)(auto ref Tsource source)
            if(isMatrixOrView!Tsource)
        {
            debug(matrix)
            {
                indent.writefln("MatrixView<%X>.opAssign()", &this);
                indent.add();
                indent.writefln("source<%X>", &source);
                indent.writeln("...");
                indent.add();
                scope(exit)
                    debug
                    {
                        indent.rem();
                        indent.rem();
                    }
            }
            linalg.storage.operations.copy(source.storage, storage);
            return this;
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

template isMatrixView(T)
{
    enum bool isMatrixView = isInstanceOf!(MatrixView, T);
}

template isMatrixOrView(T)
{
    enum bool isMatrixOrView = isMatrix!T || isMatrixView!T;
}

unittest // Regular indices
{
    debug writeln("matrix-unittest-begin");
    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(a[1, 2] == 8);
    assert((a[1, 2] = 80) == 80);
    assert((++a[1, 2]) == 81);
    assert((a[1, 2] += 3) == 84);
    debug writeln("matrix-unittest-end");
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
