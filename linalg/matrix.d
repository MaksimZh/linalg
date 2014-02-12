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
 * Memory management of matrix or vector
 */
enum MatrixMemory
{
    stat,
    bound,
    dynamic
}

/**
 * Matrix or vector or view.
 */
struct BasicMatrix(T)
{
    enum size_t nrows_ = 2;
    enum size_t ncols_ = 2;
    enum size_t[2] dimPattern = [nrows_, ncols_];

    enum StorageOrder storageOrder = defaultStorageOrder;
    alias MatrixStorageType!(T, storageOrder, nrows_, ncols_)
        StorageType;
    alias StorageType.ElementType ElementType;
    enum MatrixMemory memoryManag =
        StorageType.isStatic ? MatrixMemory.stat : MatrixMemory.dynamic;
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
    this()(auto ref StorageType storage) pure
    {
        this.storage = storage;
    }

    @property bool empty() pure const
    {
        static if(isStatic)
            return false;
        else
            return true;
    }

    public // Operations
    {
        ref auto opAssign(Tsource)(auto ref Tsource source) pure
            if(isMatrix!Tsource)
        {
            static if(memoryManag == MatrixMemory.dynamic)
                this.storage = typeof(this.storage)(source.storage);
            else
                copy(source.storage, this.storage);
            return this;
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
            BasicMatrix!(ElementType) dest;
            conjMatrix(this.storage, dest.storage);
            return dest;
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

struct Foo
{
    BasicMatrix!(int) coeffs;
}

alias BasicMatrix!(Foo) XXX;
