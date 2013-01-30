// Written in the D programming language.

/** Implementation of common features of arrays and matrices.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module base;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import aux;
import mdarray;
import stride;
import iteration;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor,   /// [0][0][0], ..., [0][0][N], [0][1][0], ...
    columnMajor /// [0][0][0], ..., [N][0][0], [0][1][0], ...
}

/** Type of the storage */
enum StorageType
{
    fixed, /// static array
    dynamic, /// dynamic array
    resizeable /// dynamic array with memory management
}

/* Storage and dimension management for arrays and matrices */
mixin template storage(T, alias dimPattern,
                       bool allowResize,
                       StorageOrder storageOrder)
{
    static assert(is(typeof(dimPattern[0]) : size_t));

    alias T ElementType; // Type of the array elements
    public enum uint rank = dimPattern.length; // Number of dimensions

    enum StorageType storageType =
        canFind(dimPattern, dynamicSize)
        ? (allowResize ? StorageType.resizeable : StorageType.dynamic)
        : StorageType.fixed;

    /* dimensions, strides and data */
    package static if(storageType == StorageType.fixed)
    {
        enum size_t[] _dim = dimPattern;
        enum size_t[] _stride =
            calcDenseStrides(_dim, storageOrder == StorageOrder.columnMajor);
        ElementType[calcDenseContainerSize(_dim)] _data;
    }
    else
    {
        size_t[rank] _dim = dimPattern;
        size_t[rank] _stride;
        ElementType[] _data;
    }

    /* Leading dimension */
    static if(dimPattern[0] != dynamicSize)
        public enum size_t length = dimPattern[0];
    else
        public size_t length() { return _dim[0]; }

    /* Full dimensions array */
    static if(storageType == StorageType.fixed)
        public enum size_t[rank] dimensions = _dim;
    else
        public @property size_t[rank] dimensions() pure const { return _dim; }

    /* Test dimensions for compatibility */
    bool isCompatibleDimensions(in size_t[] dim) pure
    {
        static if(storageType == StorageType.resizeable)
        {
            if(dim.length != rank)
                return false;
            foreach(i, d; dim)
                if((d != dimPattern[i]) && (dimPattern[i] != dynamicSize))
                    return false;
            return true;
        }
        else
        {
            return dim == _dim;
        }
    }

    /* Change dimensions */
    static if(storageType == StorageType.resizeable)
    {
        /* Recalculate strides and reallocate container for current dimensions
         */
        package void _resize() pure
        {
            _stride = calcDenseStrides(
                _dim, storageOrder == StorageOrder.columnMajor);
            _data.length = calcDenseContainerSize(_dim);
        }

        /* Change dynamic array dimensions.
           Dimensions passed to the function must be compatible.
         */
        void setAllDimensions(in size_t[] dim) pure
            in
            {
                assert(dim.length == rank);
                assert(isCompatibleDimensions(dim));
            }
        body
        {
            _dim = dim;
            _resize();
        }

        /* Change dynamic array dimensions
           Number of parameters must coincide with number of dynamic dimensions
         */
        void setDimensions(in size_t[] dim...) pure
            in
            {
                assert(dim.length == count(dimPattern, dynamicSize));
            }
        body
        {
            uint i = 0;
            foreach(d; dim)
            {
                while(dimPattern[i] != dynamicSize) ++i;
                _dim[i] = d;
                ++i;
            }
            _resize();
        }
    }
}

/** Detect whether A has storage mixin inside */
template isStorage(A)
{
    enum bool isStorage = is(typeof(()
        {
            A a;
            static assert(is(typeof(A.rank) == uint));
            static assert(is(typeof(a._dim)));
            static assert(is(typeof(a._dim[0]) == size_t));
            static assert(is(typeof(a._stride)));
            static assert(is(typeof(a._stride[0]) == size_t));
            static assert(is(typeof(a._data)));
            //XXX: DMD issue 9424
            //static assert(is(typeof(a._data[0]) == A.ElementType));
        }));
}

/* Structure to store slice boundaries compactly */
package struct SliceBounds
{
    size_t lo;
    size_t up;

    this(size_t lo_, size_t up_)
    {
        lo = lo_;
        up = up_;
    }

    this(size_t i)
    {
        lo = i;
        up = i;
    }

    // Whether this is regular slice or index
    bool isRegularSlice()
    {
        return !(lo == up);
    }
}

/* Slicing and indexing management for arrays and matrices */
mixin template sliceProxy(SourceType, alias constructSlice)
{
    /* Auxiliary structure for slicing and indexing */
    struct SliceProxy(size_t sliceRank, size_t sliceDepth)
    {
        SliceBounds[] bounds; //FIXME: dynamic array is not an optimal solution

        SourceType* source; // Pointer to the container being sliced

        package this(SourceType* source_, SliceBounds[] bounds_)
        {
            source = source_;
            bounds = bounds_;
        }

        /* Evaluate slicing result */
        static if(sliceRank > 0)
        {
            auto eval()
            {
                static if(sliceDepth < rank)
                {
                    /* If there is not enough bracket pairs - add empty [] */
                    static if(sliceDepth == rank - 1)
                        return this[];
                    else
                        return this[].eval();
                }
                else
                {
                    /* Normal slice */
                    return constructSlice!(sliceRank)(source, bounds);
                }
            }
        }
        else
        {
            /* If simple index return element by reference */
            ref auto eval()
            {
                size_t index = 0; // Position in the container
                foreach(i, b; bounds)
                    index += source._stride[i] * b.lo;
                return source._data[index];
            }
        }

        /* Slicing and indexing */
        static if(sliceDepth < dimPattern.length - 1)
        {
            /* Return slice proxy for incomplete bracket construction
            */
            SliceProxy!(sliceRank, sliceDepth + 1) opSlice()
            {
                return typeof(return)(
                    source, bounds ~ SliceBounds(0, source._dim[sliceDepth]));
            }

            SliceProxy!(sliceRank, sliceDepth + 1) opSlice(size_t lo, size_t up)
            {
                return typeof(return)(source, bounds ~ SliceBounds(lo, up));
            }

            SliceProxy!(sliceRank - 1, sliceDepth + 1) opIndex(size_t i)
            {
                return typeof(return)(source, bounds ~ SliceBounds(i));
            }
        }
        else static if(sliceDepth == (dimPattern.length - 1))
             {
                 /* If only one more slicing can be done
                    then return slice not proxy
                 */
                 auto opSlice()
                 {
                     return SliceProxy!(sliceRank, sliceDepth + 1)(
                         source,
                         bounds ~ SliceBounds(0, source._dim[sliceDepth])
                         ).eval();
                 }

                 auto opSlice(size_t lo, size_t up)
                 {
                     return SliceProxy!(sliceRank, sliceDepth + 1)(
                         source, bounds ~ SliceBounds(lo, up)).eval();
                 }

                 static if(sliceRank > 1)
                 {
                     auto opIndex(size_t i)
                     {
                         return SliceProxy!(sliceRank - 1, sliceDepth + 1)(
                             source, bounds ~ SliceBounds(i)).eval();
                     }
                 }
                 else
                 {
                     /* If simple index return element by reference */
                     ref auto opIndex(size_t i)
                     {
                         return SliceProxy!(sliceRank - 1, sliceDepth + 1)(
                             source, bounds ~ SliceBounds(i)).eval();
                     }
                 }
             }

        auto opCast(Tresult)()
        {
            return cast(Tresult)(eval());
        }
    }

    /* Slicing and indexing */
    SliceProxy!(rank, 1) opSlice()
    {
        return typeof(return)(&this, [SliceBounds(0, _dim[0])]);
    }

    SliceProxy!(rank, 1) opSlice(size_t lo, size_t up)
    {
        return typeof(return)(&this, [SliceBounds(lo, up)]);
    }

    SliceProxy!(rank - 1, 1) opIndex(size_t i)
    {
        return typeof(return)(&this, [SliceBounds(i)]);
    }
}

/* Operations that are common for both arrays and matrices */
mixin template basicOperations(FinalType,
                               StorageType storageType,
                               StorageOrder storageOrder)
{
    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _data);
    }

    ByElement!(ElementType) byElement()
    {
        return ByElement!(ElementType)(_dim, _stride, _data);
    }

    ref auto opAssign(SourceType)(SourceType source)
        if(isStorage!SourceType)
            in
            {
                assert(isCompatibleDimensions(source._dim));
            }
    body
    {
        static if(storageType == StorageType.resizeable)
            if(_dim != source._dim)
                setAllDimensions(source._dim);
        iteration.copy(source.byElement(), this.byElement());
        return this;
    }

    bool opEquals(SourceType)(SourceType source)
        if(isStorage!SourceType)
            in
            {
                assert(source._dim == _dim);
            }
    body
    {
        return equal(source.byElement(), this.byElement());
    }

    FinalType opUnary(string op)()
        if(((op == "-") || (op == "+"))
           && (is(typeof(mixin(op ~ "this.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        iteration.applyUnary!op(this.byElement(), result.byElement());
        return result;
    }

    FinalType opBinary(string op, Trhs)(Trhs rhs)
        if(((op == "-") || (op == "+") || (op == "*") || (op == "/"))
           && isStorage!Trhs
           && (is(typeof(mixin("this.byElement().front"
                               ~ op ~ "rhs.byElement().front")))))
    {
        FinalType result;
        static if(result.storageType == StorageType.resizeable)
            result.setAllDimensions(_dim);
        iteration.applyBinary!op(this.byElement(),
                                 rhs.byElement(),
                                 result.byElement());
        return result;
    }
}
