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
}

unittest
{
    debug writeln("matrix-unittest-begin");
    auto a = Matrix!(int, 4, 6)(array(iota(24)));
    assert(a[1, 2] == 8);
    assert((a[1, 2] = 80) == 80);
    assert((++a[1, 2]) == 81);
    assert((a[1, 2] += 3) == 84);
    debug writeln("matrix-unittest-end");
}
