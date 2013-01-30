// Written in the D programming language.

/** Matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.matrix;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import linalg.base;
import linalg.aux;
import linalg.mdarray;
import linalg.stride;
import linalg.iteration;

/* Operations specific for arrays */
mixin template matrixOperations(FinalType,
                                StorageType storageType,
                                StorageOrder storageOrder)
{
    //XXX: DMD issue 9235: + and - should be in linalg.base.basicOperations
    FinalType opBinary(string op, Trhs)(Trhs rhs)
        if(((op == "-") || (op == "+"))
           && isStorage!Trhs
           && (is(typeof(mixin("this.byElement().front"
                               ~ op ~ "rhs.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        linalg.iteration.applyBinary!op(this.byElement(),
                                        rhs.byElement(),
                                        result.byElement());
        return result;
    }
}

/** Multidimensional compact array
*/
struct Matrix(T, size_t nrows, size_t ncols,
              StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    enum StorageOrder storageOrder = storageOrder_;
    enum size_t[] dimPattern = [nrows, ncols];

    mixin storage!(T, dimPattern, true, storageOrder);

    static if(storageType == StorageType.fixed)
        // Convert ordinary 1D array to static MD array with dense storage
        this(T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _data = source;
        }
    else
        /* Convert ordinary 1D array to dense multidimensional array
           with given dimensions
         */
        this(T[] source, size_t nrows, size_t ncols)
            in
            {
                assert(isCompatibleDimensions([nrows, ncols]));
            }
        body
        {
            _data = source;
            _dim = [nrows, ncols];
            _stride = calcDenseStrides(
                _dim, storageOrder == StorageOrder.columnMajor);
        }

    mixin basicOperations!(Matrix, storageType, storageOrder);
    mixin matrixOperations!(Matrix, storageType, storageOrder);
}

unittest // Type properties and dimensions
{
    {
        alias Matrix!(double, dynamicSize, dynamicSize) A;
        static assert(is(A.ElementType == double));
        static assert(A.storageType == StorageType.resizeable);
        static assert(A.storageOrder == StorageOrder.rowMajor);
        A a = A(array(iota(12.0)), 3, 4);
        assert(a.dimensions == [3, 4]);
    }
}
