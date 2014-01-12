// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.array;

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

import linalg.operations.basic;


alias linalg.storage.slice.Slice Slice; //NOTE: waiting for proper slice support

/*
********************************************************************************
  1D array 
********************************************************************************
*/

template Array1D(T, size_t dim)
{
    alias BasicArray1D!(T, dim, false) Array1D;
}

template ArrayView1D(T, size_t dim)
{
    alias BasicArray1D!(T, dim, true) ArrayView1D;
}

/**
 * Array or view.
 */
struct BasicArray1D(T, size_t dim_, bool isBound_)
{
    /** Dimensions pattern */
    enum size_t dimPattern = dim_;

    /* Select storage type.
     * Note: vectors use 1d storage (mainly for optimization)
     */
    alias StorageRegular1D!(T, dim_) StorageType;
    /** Type of matrix elements */
    alias StorageType.ElementType ElementType;
    /** Storage order */
    enum bool isStatic = StorageType.isStatic;
    enum bool isBound = isBound_;

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

    /**
     * If matrix is static then create a copy of the source.
     * Otherwise share the source data.
     */
    this(Tsource)(auto ref Tsource source) pure
    if(isArray1D!Tsource)
    {
        this = source;
    }

    static if(isStatic)
    {
        /** Create static shallow copy of array and wrap it. */
        this()(ElementType[] array) pure
        {
            storage = StorageType(array);
        }
    }
    else
    {
        /** Allocate new 1D array with given dimensions */
        this()(size_t dim) pure
        {
            this(StorageType(dim));
        }

        /** Wrap array with an array */
        this()(ElementType[] array) pure
        {
            this(StorageType(array));
        }
    }

    public // Dimensions
    {
        /** Dimensions of array */
        @property size_t dim() pure { return storage.dim; } //ditto

        /** Test dimensions for compatibility */
        static bool isCompatDim(in size_t dim) pure
        {
            return StorageType.isCompatDim(dim);
        }

        static if(!isStatic)
        {
            /** Set dimensions of array */
            void setDim(in size_t dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                storage.setDim(dim);
            }
        }

        /**
         * Whether array is empty (not allocated).
         * Always false for static array.
         */
        @property bool empty() pure
        {
            static if(isStatic)
                return false;
            else
                return dim == 0;
        }
    }

    public // Slices and indices support
    {
        //NOTE: depends on DMD pull-request 443
        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure
        {
            return storage.opDollar!dimIndex;
        }

        ref auto opIndex() pure
        {
            return ArrayView1D!(ElementType, dynsize)(
                storage.opIndex());
        }

        ref auto opIndex(size_t i) pure
        {
            return storage[i];
        }

        ref auto opIndex(Slice s) pure
        {
            return ArrayView1D!(ElementType, dynsize)(
                storage.opIndex(s));
        }
    }

    /* Cast to built-in array */
    ElementType[] opCast() pure
    {
        return cast(typeof(return)) storage;
    }

    /** Create shallow copy of array */
    @property auto dup() pure
    {
        return Array1D!(ElementType, dynsize)(this.storage.dup);
    }

    public // Operations
    {
        ref auto opAssign(Tsource)(auto ref Tsource source) pure
            if(isArray1D!Tsource)
        {
            static if(!isStatic && !isBound)
                this.storage = typeof(this.storage)(source.storage);
            else
                if(source.empty)
                    fill(zero!(Tsource.ElementType), this.storage);
                else
                    copy(source.storage, this.storage);
            return this;
        }

        bool opEquals(Tsource)(auto ref Tsource source) pure
            if(isArray1D!Tsource)
        {
            return compare(source.storage, this.storage);
        }
    }
}

/**
 * Detect whether T is 1D array
 */
template isArray1D(T)
{
    enum bool isArray1D = isInstanceOf!(BasicArray1D, T);
}

unittest // Type properties
{
    alias Array1D!(int, 3) Ai3;
    alias Array1D!(int, dynsize) Aid;

    // dimPattern
    static assert(Ai3.dimPattern == 3);
    static assert(Aid.dimPattern == dynsize);
    
    // ElementType
    static assert(is(Ai3.ElementType == int));

    // isStatic
    static assert(Ai3.isStatic);
    static assert(!(Aid.isStatic));
}

unittest // Constructors, cast
{
    int[] a = [1, 2, 3];

    assert(cast(int[]) Array1D!(int, 3)(a)
           == [1, 2, 3]);
    assert(cast(int[]) Array1D!(int, dynsize)(3)
           == [0, 0, 0]);
    assert(cast(int[]) Array1D!(int, dynsize)(a)
           == [1, 2, 3]);
    auto aa = Array1D!(int, 3)(a);
    {
        Array1D!(int, 3) ab = aa;
        assert(cast(int[]) ab
               == [1, 2, 3]);
    }
    {
        Array1D!(int, dynsize) ab = aa;
        assert(cast(int[]) ab
               == [1, 2, 3]);
    }
}

unittest // Storage direct access
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Storage direct access");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = Array1D!(int, dynsize)(src);
    assert(a.storage.container.ptr == src.ptr);
    assert(a.storage.container == [1, 2, 3, 4, 5, 6]);
    assert(a.storage.dim == 6);
    assert(a.storage.stride == 1);
}

unittest // Dimension control
{
    debug(unittests)
    {
        debugOP.writeln("linalg.matrix unittest: Dimension control");
        mixin(debugIndentScope);
    }
    else debug mixin(debugSilentScope);

    Array1D!(int, dynsize) a;
    assert(a.empty);
    assert(a.dim == 0);
    a.setDim(3);
    assert(!(a.empty));
    assert(a.dim == 3);
    assert(a.isCompatDim(33));

    Array1D!(int, 3) b;
    assert(!(b.empty));
    assert(b.dim == 3);
    assert(!(b.isCompatDim(33)));
}

unittest // Comparison
{
    int[] src1 = [1, 2, 3];
    int[] src2 = [3, 2, 1];

    {
        auto a = Array1D!(int, 3)(src1);
        auto b = Array1D!(int, 3)(src1);
        auto c = Array1D!(int, 3)(src2);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Array1D!(int, 3)(src1);
        auto b = Array1D!(int, dynsize)(src1);
        auto c = Array1D!(int, dynsize)(src2);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Array1D!(int, dynsize)(src1);
        auto b = Array1D!(int, dynsize)(src1);
        auto c = Array1D!(int, dynsize)(src2);
        assert(a == b);
        assert(a != c);
    }
}

unittest // Copying
{
    int[] src = [1, 2, 3];
    int[] msrc = src.dup;

    {
        auto a = Array1D!(int, 3)(src);
        Array1D!(int, 3) b;
        auto c = (b = a);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Array1D!(int, 3)(msrc);
        Array1D!(int, dynsize) b;
        auto c = (b = a);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Array1D!(int, 3)(src);
        Array1D!(int, dynsize) b;
        auto c = (b = a.dup);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
    {
        auto a = Array1D!(int, dynsize)(msrc);
        Array1D!(int, 3) b;
        auto c = (b = a);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Array1D!(int, dynsize)(msrc);
        Array1D!(int, dynsize) b;
        auto c = (b = a);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Array1D!(int, dynsize)(msrc);
        Array1D!(int, dynsize) b;
        auto c = (b = a.dup);
        assert(b == a);
        assert(c == a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
}

unittest // Regular indices
{
    auto a = Array1D!(int, 6)(array(iota(6)));
    assert(a[1] == 1);
    assert((a[1] = 10) == 10);
    assert(a[1] == 10);
    ++a[1];
    assert(a[1] == 11);
    a[1] += 3;
    assert(a[1] == 14);
}

unittest // Slices
{
    auto a = Array1D!(int, 6)(array(iota(6)));
    assert(cast(int[]) a[Slice(1, 5, 3)] == [1, 4]);
    a[Slice(1, 5, 3)] = Array1D!(int, 2)([101, 104]);
    assert(cast(int[]) a == [0, 101, 2, 3, 104, 5]);
}

/*
********************************************************************************
  2D array 
********************************************************************************
*/

template Array2D(T, size_t nrows_, size_t ncols_,
                 StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicArray2D!(T, nrows_, ncols_, storageOrder_, false) Array2D;
}

template ArrayView2D(T, size_t nrows_, size_t ncols_,
                     StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicArray2D!(T, nrows_, ncols_, storageOrder_, true) ArrayView2D;
}

/**
 * Array or view.
 */
struct BasicArray2D(T, size_t nrows_, size_t ncols_,
                    StorageOrder storageOrder_, bool isBound_)
{
    /** Dimensions pattern */
    enum size_t[2] dimPattern = [nrows_, ncols_];

    /* Select storage type.
     * Note: vectors use 1d storage (mainly for optimization)
     */
    alias StorageRegular2D!(T, storageOrder_, nrows_, ncols_)
        StorageType;
    /** Type of matrix elements */
    alias StorageType.ElementType ElementType;
    /** Storage order */
    enum StorageOrder storageOrder = storageOrder_;
    enum bool isStatic = StorageType.isStatic;
    enum bool isBound = isBound_;

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

    /**
     * If matrix is static then create a copy of the source.
     * Otherwise share the source data.
     */
    this(Tsource)(auto ref Tsource source) pure
    if(isArray2D!Tsource)
    {
        this = source;
    }

    static if(isStatic)
    {
        /** Create static shallow copy of array and wrap it. */
        this()(ElementType[] array) pure
        {
            storage = StorageType(array);
        }
    }
    else
    {
        /** Allocate new 2D array with given dimensions */
        this()(size_t nrows, size_t ncols) pure
        {
            this(StorageType([nrows, ncols]));
        }

        /** Wrap array with an array with given dimensions */
        this()(ElementType[] array,
               size_t nrows, size_t ncols) pure
        {
            this(StorageType(array, [nrows, ncols]));
        }
    }

    public // Dimensions
    {
        /** Dimensions of array */
        @property size_t nrows() pure { return storage.nrows; }
        @property size_t ncols() pure { return storage.ncols; } //ditto
        @property size_t[2] dim() pure { return [nrows, ncols]; } //ditto

        /** Test dimensions for compatibility */
        static bool isCompatDim(in size_t[2] dim) pure
        {
            return StorageType.isCompatDim(dim);
        }

        static if(!isStatic)
        {
            /** Set dimensions of array */
            void setDim(in size_t[2] dim) pure
                in
                {
                    assert(isCompatDim(dim));
                }
            body
            {
                storage.setDim(dim);
            }
        }

        /**
         * Whether array is empty (not allocated).
         * Always false for static array.
         */
        @property bool empty() pure
        {
            static if(isStatic)
                return false;
            else
                return nrows*ncols == 0;
        }
    }

    public // Slices and indices support
    {
        //NOTE: depends on DMD pull-request 443
        mixin sliceOverload;

        size_t opDollar(size_t dimIndex)() pure
        {
            return storage.opDollar!dimIndex;
        }

        ref auto opIndex() pure
        {
            return ArrayView2D!(ElementType,
								dynsize, dynsize,
								storageOrder)(
									storage.opIndex());
        }

        ref auto opIndex(size_t irow, size_t icol) pure
        {
            return storage[irow, icol];
        }

        ref auto opIndex(Slice srow, size_t icol) pure
        {
            return ArrayView1D!(ElementType,
								dynsize,
								storageOrder)(
									storage.opIndex(srow, icol));
        }

        ref auto opIndex(size_t irow, Slice scol) pure
        {
            return ArrayView1D!(ElementType,
								dynsize,
								storageOrder)(
									storage.opIndex(irow, scol));
        }

        ref auto opIndex(Slice srow, Slice scol) pure
        {
            return ArrayView2D!(ElementType,
								dynsize, dynsize,
								storageOrder)(
									storage.opIndex(srow, scol));
        }
    }

    /* Cast to built-in array */
    ElementType[][] opCast() pure
    {
        return cast(typeof(return)) storage;
    }

    /** Create shallow copy of array */
    @property auto dup() pure
    {
        return Array2D!(ElementType,
						dynsize, dynsize,
						storageOrder)(this.storage.dup);
    }
}

/**
 * Detect whether T is 2D array
 */
template isArray2D(T)
{
    enum bool isArray2D = isInstanceOf!(BasicArray2D, T);
}
