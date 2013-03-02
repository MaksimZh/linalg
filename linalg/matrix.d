// Written in the D programming language.

module linalg.matrix;

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
