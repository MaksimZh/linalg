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

template Array1D(T, size_t dim = dynsize)
{
    alias BasicArray1D!(T, dim, false) Array1D;
}

template ArrayView1D(T, size_t dim = dynsize)
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

template Array2D(T, size_t nrows = dynsize, size_t ncols = dynsize,
                 StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicArray2D!(T, nrows, ncols, storageOrder_, false) Array2D;
}

template ArrayView2D(T, size_t nrows = dynsize, size_t ncols = dynsize,
                     StorageOrder storageOrder_ = defaultStorageOrder)
{
    alias BasicArray2D!(T, nrows, ncols, storageOrder_, true) ArrayView2D;
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
            return ArrayView1D!(ElementType, dynsize)(
                storage.opIndex(srow, icol));
        }

        ref auto opIndex(size_t irow, Slice scol) pure
        {
            return ArrayView1D!(ElementType, dynsize)(
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

    public // Operations
    {
        ref auto opAssign(Tsource)(auto ref Tsource source) pure
            if(isArray2D!Tsource)
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
            if(isArray2D!Tsource)
        {
            return compare(source.storage, this.storage);
        }
    }
}

/**
 * Detect whether T is 2D array
 */
template isArray2D(T)
{
    enum bool isArray2D = isInstanceOf!(BasicArray2D, T);
}

unittest // Type properties
{
    alias Array2D!(int, 2, 3) Ai23;
    alias Array2D!(int, 2, 3, StorageOrder.row) Ai23r;
    alias Array2D!(int, 2, 3, StorageOrder.col) Ai23c;
    alias Array2D!(int, dynsize, 3) Aid3;
    alias Array2D!(int, 1, 3) Ai13;
    alias Array2D!(int, 2, 1) Ai21;
    alias Array2D!(int, dynsize, dynsize) Aidd;
    alias Array2D!(int, 1, dynsize) Ai1d;
    alias Array2D!(int, dynsize, 1) Aid1;

    // dimPattern
    static assert(Ai23.dimPattern == [2, 3]);
    static assert(Aid3.dimPattern == [dynsize, 3]);

    // storageOrder
    static assert(Ai23.storageOrder == defaultStorageOrder);
    static assert(Ai23r.storageOrder == StorageOrder.row);
    static assert(Ai23c.storageOrder == StorageOrder.col);

    // ElementType
    static assert(is(Ai23.ElementType == int));

    // isStatic
    static assert(Ai23.isStatic);
    static assert(!(Aid3.isStatic));
    static assert(!(Ai1d.isStatic));
    static assert(!(Aidd.isStatic));
}

unittest // Constructors, cast
{
    int[] a = [1, 2, 3, 4, 5, 6];

    assert(cast(int[][]) Array2D!(int, dynsize, dynsize)(
               StorageRegular2D!(int, StorageOrder.row, dynsize, dynsize)(
                   a, [2, 3]))
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) Array2D!(int, 2, 3)(a)
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) Array2D!(int, 1, 3)(a[0..3])
           == [[1, 2, 3]]);
    assert(cast(int[][]) Array2D!(int, 3, 1)(a[0..3])
           == [[1],
               [2],
               [3]]);
    assert(cast(int[][]) Array2D!(int, 1, dynsize)(a[0..3], 1, 3)
           == [[1, 2, 3]]);
    assert(cast(int[][]) Array2D!(int, dynsize, 1)(a[0..3], 3, 1)
           == [[1],
               [2],
               [3]]);
    assert(cast(int[][]) Array2D!(int, 1, dynsize)(1, 3)
           == [[0, 0, 0]]);
    assert(cast(int[][]) Array2D!(int, dynsize, dynsize)(2, 3)
           == [[0, 0, 0],
               [0, 0, 0]]);
    assert(cast(int[][]) Array2D!(int, dynsize, dynsize)(2, 3)
           == [[0, 0, 0],
               [0, 0, 0]]);
    assert(cast(int[][]) Array2D!(int, dynsize, dynsize)(a, 2, 3)
           == [[1, 2, 3],
               [4, 5, 6]]);
    auto ma = Array2D!(int, 2, 3)(a);
    {
        Array2D!(int, 2, 3) mb = ma;
        assert(cast(int[][]) mb
               == [[1, 2, 3],
                   [4, 5, 6]]);
    }
    {
        Array2D!(int, dynsize, dynsize) mb = ma;
        assert(cast(int[][]) mb
               == [[1, 2, 3],
                   [4, 5, 6]]);
    }
}

unittest // Storage direct access
{
    int[] src = [1, 2, 3, 4, 5, 6];

    auto a = Array2D!(int, dynsize, dynsize, StorageOrder.row)(src, 2, 3);
    assert(a.storage.container.ptr == src.ptr);
    assert(a.storage.container == [1, 2, 3, 4, 5, 6]);
    assert(a.storage.dim == [2, 3]);
    assert(a.storage.stride == [3, 1]);
}

unittest // Dimension control
{
    Array2D!(int, dynsize, dynsize) a;
    assert(a.empty);
    assert(a.nrows == 0);
    assert(a.ncols == 0);
    assert(a.dim == [0, 0]);
    a.setDim([2, 3]);
    assert(!(a.empty));
    assert(a.nrows == 2);
    assert(a.ncols == 3);
    assert(a.dim == [2, 3]);
    assert(a.isCompatDim([22, 33]));

    Array2D!(int, 2, 3) b;
    assert(!(b.empty));
    assert(b.nrows == 2);
    assert(b.ncols == 3);
    assert(b.dim == [2, 3]);
    assert(!(b.isCompatDim([22, 33])));
}

unittest // Comparison
{
    int[] src1 = [1, 2, 3, 4, 5, 6];
    int[] src2 = [6, 5, 4, 3, 2, 1];

    {
        auto a = Array2D!(int, 2, 3)(src1);
        auto b = Array2D!(int, 2, 3)(src1);
        auto c = Array2D!(int, 2, 3)(src2);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Array2D!(int, 2, 3)(src1);
        auto b = Array2D!(int, dynsize, dynsize)(src1, 2, 3);
        auto c = Array2D!(int, dynsize, dynsize)(src2, 2, 3);
        assert(a == b);
        assert(a != c);
    }
    {
        auto a = Array2D!(int, dynsize, dynsize)(src1, 2, 3);
        auto b = Array2D!(int, dynsize, dynsize)(src1, 2, 3);
        auto c = Array2D!(int, dynsize, dynsize)(src2, 2, 3);
        assert(a == b);
        assert(a != c);
    }
}

unittest // Copying
{
    int[] src = [1, 2, 3, 4, 5, 6];
    int[] msrc = src.dup;

    {
        auto a = Array2D!(int, 2, 3)(src);
        Array2D!(int, 2, 3) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Array2D!(int, 2, 3)(msrc);
        Array2D!(int, dynsize, dynsize) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Array2D!(int, 2, 3)(src);
        Array2D!(int, dynsize, dynsize) b;
        auto c = (b = a.dup);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
    {
        auto a = Array2D!(int, dynsize, dynsize)(msrc, 2, 3);
        Array2D!(int, 2, 3) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr != b.storage.container.ptr);
    }
    {
        auto a = Array2D!(int, dynsize, dynsize)(msrc, 2, 3);
        Array2D!(int, dynsize, dynsize) b;
        auto c = (b = a);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr == a.storage.container.ptr);
        assert(c.storage.container.ptr == a.storage.container.ptr);
    }
    {
        auto a = Array2D!(int, dynsize, dynsize)(msrc, 2, 3);
        Array2D!(int, dynsize, dynsize) b;
        auto c = (b = a.dup);
        assert(cast(int[][]) b == cast(int[][]) a);
        assert(cast(int[][]) c == cast(int[][]) a);
        assert(b.storage.container.ptr != a.storage.container.ptr);
        assert(c.storage.container.ptr == b.storage.container.ptr);
    }
}

unittest // Regular indices
{
    auto a = Array2D!(int, 4, 6)(array(iota(24)));
    assert(a[1, 2] == 8);
    assert((a[1, 2] = 80) == 80);
    assert(a[1, 2] == 80);
    ++a[1, 2];
    assert(a[1, 2] == 81);
    a[1, 2] += 3;
    assert(a[1, 2] == 84);
}

unittest // Slices
{
    auto a = Array2D!(int, 4, 6)(array(iota(24)));
    assert(cast(int[]) a[1, Slice(1, 5, 3)]
           == [7, 10]);
    assert(cast(int[]) a[Slice(1, 4, 2), 1]
           == [7, 19]);
    assert(cast(int[][]) a[Slice(1, 4, 2), Slice(1, 5, 3)]
           == [[7, 10],
               [19, 22]]);

    a[Slice(1, 4, 2), Slice(1, 5, 3)] =
        Array2D!(int, 2, 2)(array(iota(101, 105)));
    assert(cast(int[][]) a
           == [[0, 1, 2, 3, 4, 5],
               [6, 101, 8, 9, 102, 11],
               [12, 13, 14, 15, 16, 17],
               [18, 103, 20, 21, 104, 23]]);
}
