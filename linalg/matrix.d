// Written in the D programming language.

module linalg.matrix;

import std.traits;

debug import std.stdio;

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
            storage = StorageType(array);
        }
    }
    else
    {
        inout this(inout ElementType[] array, size_t nrows_, size_t ncols_) pure
        {
            storage = StorageType(array, [nrows_, ncols_]);
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
                        pSource.storage.sliceView(bounds, SliceBounds(i)));
                }
            }

            ref inout auto opSlice() pure inout
            {
                return MatrixView!(StorageType, isIndex, false)(
                    pSource.storage.sliceView(
                        bounds, SliceBounds(0, pSource.ncols)));
            }

            ref inout auto opSlice(size_t lo, size_t up) pure inout
            {
                return MatrixView!(StorageType, isIndex, false)(
                    pSource.storage.sliceView(bounds, SliceBounds(lo, up)));
            }
        }
    }

    public // Assignment
    {
        auto opAssign(Tsource)(Tsource source)
            if(isMatrixOrView!Tsource)
        {
            linalg.storage.operations.copy(source.storage, storage);
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
    inout this(inout StorageType storage_) pure
    {
        storage = storage_;
    }

    public // Assignment
    {
        auto opAssign(Tsource)(Tsource source)
            if(isMatrixOrView!Tsource)
        {
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
    alias Matrix!(int, 3, 4) A;
    A a, b;
    debug writeln("in");
    a = A(array(iota(12)));
    debug writeln("out");
    auto test = [[0, 1, 2, 3],
                 [4, 5, 6, 7],
                 [8, 9, 10, 11]];
    assert(cast(int[][])a == test);
    debug writeln(cast(int[][])(a));
    debug writeln(cast(int[][])(b = a));
    assert(cast(int[][])(b = a) == test);
    assert(cast(int[][])b == test);
    alias Matrix!(int, dynamicSize, dynamicSize) A1;
    A1 a1, b1;
    a1 = A1(array(iota(12)), 3, 4);
    assert(cast(int[][])(b1 = a1) == test);
    assert(cast(int[][])b1 == test);
}
