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

/* Slicing and indexing management for arrays and matrices */
mixin template matrixSliceProxy(SourceType, alias constructSlice)
{
    /* Auxiliary structure for slicing and indexing */
    struct SliceProxy(bool isRegular)
    {
        SliceBounds bounds;

        SourceType* source; // Pointer to the container being sliced

        package this(SourceType* source_, SliceBounds bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        /* Evaluate slicing result.
           Calling this method means that bracket set is incomplete.
           Just adds empty pair: []
        */
        auto eval()
        {
            return this[];
        }

        /* Slicing and indexing */
        static if(isRegular)
        {
            /* Slice of regular (multirow) slice can be a matrix
               and can't be access to element by index
            */

            auto opSlice()
            {
                /* Slice is a matrix (rank = 2) */
                return constructSlice!(true, true)(
                    source, bounds, SliceBounds(0, source._dim[1]));
            }

            auto opSlice(size_t lo, size_t up)
            {
                /* Slice is a matrix (rank = 2) */
                return constructSlice!(true, true)(
                    source, bounds, SliceBounds(lo, up));
            }

            auto opIndex(size_t i)
            {
                /* Slice is a vector (rank = 1) */
                return constructSlice!(true, false)(
                    source, bounds, SliceBounds(i));
            }
        }
        else
        {
            /* Slice of one row (multirow) can be a vector
               or access to element by index
            */

            auto opSlice()
            {
                /* Slice is a vector (rank = 1) */
                return constructSlice!(false, true)(
                    source, bounds, SliceBounds(0, source._dim[1]));
            }

            auto opSlice(size_t lo, size_t up)
            {
                /* Slice is a vector (rank = 1) */
                return constructSlice!(false, true)(
                    source, bounds, SliceBounds(lo, up));
            }

            ref auto opIndex(size_t i)
            {
                /* Access to an element by index */
                return source._data[source._stride[0] * bounds.lo
                                    + source._stride[1] * i];
            }
        }

        auto opCast(Tresult)()
        {
            return cast(Tresult)(eval());
        }
    }

    /* Slicing and indexing */
    SliceProxy!(true) opSlice()
    {
        return typeof(return)(&this, SliceBounds(0, _dim[0]));
    }

    SliceProxy!(true) opSlice(size_t lo, size_t up)
    {
        return typeof(return)(&this, SliceBounds(lo, up));
    }

    SliceProxy!(false) opIndex(size_t i)
    {
        return typeof(return)(&this, SliceBounds(i));
    }
}

/** Matrix view
*/
struct MatrixView(T, bool multMajor, bool multMinor,
                  StorageOrder storageOrder_ = StorageOrder.rowMajor)
{
    enum StorageOrder storageOrder = storageOrder_;
    enum size_t[] dimPattern = [multMajor ? dynamicSize : 1,
                                multMinor ? dynamicSize : 1];
    alias Matrix!(T, dimPattern[0], dimPattern[1], storageOrder_) MatrixType;

    mixin storage!(T, dimPattern, true, storageOrder);

    package this(SourceType)(ref SourceType source,
                             SliceBounds boundsMajor, SliceBounds boundsMinor)
        if(isStorage!SourceType)
    {
        /* Lower boundary in the container */
        size_t bndLo =
            source._stride[0] * boundsMajor.lo
            + source._stride[1] * boundsMinor.lo;
        /* Upper boundary in the container */
        size_t bndUp =
            source._stride[0]
            * (multMajor ? boundsMajor.up - 1 : boundsMajor.up)
            +
            source._stride[1]
            * (multMinor ? boundsMinor.up - 1 : boundsMinor.up);

        _dim = [source._dim[0] + (multMajor ? 0 : 1),
                source._dim[1] + (multMinor ? 0 : 1)];
        _stride = source._stride;
        _data = source._data[bndLo..bndUp];
    }

    mixin basicOperations!(MatrixType, storageType, storageOrder);
    mixin matrixOperations!(MatrixType, storageType, storageOrder);
}

/** Matrix
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

    /* Slicing and indexing */
    auto constructSlice(bool isRegMajor, bool isRegMinor)(
        Matrix* source, SliceBounds boundsMajor, SliceBounds boundsMinor)
    {
        return MatrixView!(T, isRegMajor, isRegMinor, storageOrder)(
            *source, boundsMajor, boundsMinor);
    }

    mixin matrixSliceProxy!(Matrix, Matrix.constructSlice);

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
