// Written in the D programming language.

/** This module contains the $(LREF Arrax) .

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
/* Possible problems:

   Probably some symbol names should be replaced with better ones.
   
   Grammar and spelling should be fixed especially in comments and embedded documentation.
   
   SliceProxy evaluates to array slice.
   Copy on write technique may require copying values densely to another container.
   This is hard to organize if COW is implemented on container level.
 */
module arrax;

import std.algorithm;

debug import std.stdio;

version(unittest)
{
    import std.array;
    import std.range;
}

import stride;
import mdarray;
import aux;
import iteration;

// Value to denote not fixed dimension of the array
enum size_t dynamicSize = 0;

/* Detect whether A is a dense multidimensional array or slice
 */
template isArrayOrSlice(A)
{
    enum bool isArrayOrSlice = is(typeof(()
        {
            A a;
            alias A.ElementType T;
            static assert(is(typeof(A.rank) == uint));
            static assert(is(typeof(A.isDynamic) == bool));
            static assert(is(typeof(a._dim)));
            static assert(is(typeof(a._dim[0]) == size_t));
            static assert(is(typeof(a._stride)));
            static assert(is(typeof(a._stride[0]) == size_t));
            static assert(is(typeof(a._container)));
            static assert(is(typeof(a._container[0]) == T));
        }));
}

unittest // isArrayOrSlice
{
    static assert(isArrayOrSlice!(Arrax!(int, 2, 3, 4)));
    static assert(isArrayOrSlice!(Arrax!(int, 2, 3, 0)));
    static assert(isArrayOrSlice!(ArraxSlice!(int, 2)));
}

mixin template IteratorByElementGeneric(ArrayType)
{
    //TODO: optimize
    struct ByElement
    {
        private ArrayType* _source;
        private ElementType* _ptr;
        private size_t[rank] _index;
        private bool _empty;

        this(ArrayType* source)
        {
            _source = source;
            _ptr = _source._container.ptr;
            _index[] = 0;
            _empty = false;
        }

        @property bool empty() { return _empty; }
        @property ref ElementType front() { return *_ptr; }
        void popFront()
        {
            int i = rank - 1;
            while((i >= 0) && (_index[i] == _source._dim[i] - 1))
            {
                _ptr -= _source._stride[i] * _index[i];
                _index[i] = 0;
                --i;
            }
            if(i >= 0)
            {
                _ptr += _source._stride[i];
                ++_index[i];
            }
            else
                _empty = true;
        }
    }

    ByElement byElement()
    {
        return ByElement(&this);
    }
}

// Structure to store slice boundaries compactly
struct SliceBounds
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

/* Multidimensional array slice.
   Unlike arrays slices do not perform memory management.
   Their dimensions and stride of slice are calculated only once
   and can not be changed.
   Currently they are used only for data copying.
   Support of other operations (like arithmetic) is planned.
   For other procedures they should be converted to dense arrays.
 */
struct ArraxSlice(T, uint rank_)
{
    alias T ElementType;
    enum uint rank = rank_;
    enum bool isDynamic = true;
    
    size_t[rank] _dim;
    size_t[rank] _stride;
    ElementType[] _container;

    // Make slice of a built-in array
    this()(T[] source, size_t[] dim, size_t[] stride = [])
        in
        {
            assert(dim.length == rank);
            assert(!((stride != []) && (stride.length != rank)));
            if(stride != [])
            {
                size_t requiredSize = 0;
                foreach(i, d; dim)
                    requiredSize += stride[i] * (dim[i] - 1);
                ++requiredSize;
                assert(source.length == requiredSize);
            }
            else
                assert(source.length == reduce!("a * b")(dim));
        }
    body
    {
        _container = source;
        _dim = dim;
        // If strides are not specified create a dense array
        if(stride != [])
            _stride = stride;
        else
            _stride = calcDenseStrides(_dim);
    }

    // Make slice of an array or slice
    this(SourceType)(ref SourceType source, SliceBounds[] bounds)
        if(isArrayOrSlice!SourceType)
            in
            {
                assert(bounds.length == source.rank);
                assert(count!("a.isRegularSlice")(bounds) == rank);
            }
    body
    {
        size_t bndLo = 0; // Lower boundary in the container
        size_t bndUp = 0; // Upper boundary in the container

        /* Dimensions and strides should be copied for all regular slices
           and omitted for indices.
           Boundaries should not cover additional elements.
        */
        uint idest = 0;
        foreach(i, b; bounds)
        {
            bndLo += source._stride[i] * b.lo;
            if(b.isRegularSlice)
            {
                bndUp += source._stride[i] * (b.up - 1);
                _dim[idest] = b.up - b.lo;
                _stride[idest] = source._stride[i];
                ++idest;
            }
            else
                bndUp += source._stride[i] * b.up;
        }
        ++bndUp;

        _container = source._container[bndLo..bndUp];
    }

    public // Iterators
    {
        mixin IteratorByElementGeneric!(ArraxSlice);
    }

    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _container);
    }
    
    ref ArraxSlice opAssign(SourceType)(SourceType source)
        if(isArrayOrSlice!SourceType)
            in
            {
                assert(source._dim == _dim);
            }
    body
    {
        iteration.copy(source.byElement(), this.byElement());
        return this;
    }

    bool opEquals(SourceType)(SourceType source)
        if(isArrayOrSlice!SourceType)
            in
            {
                assert(source._dim == _dim);
            }
    body
    {
        auto iter = byElement;
        auto iterSource = source.byElement;
        foreach(v; iter)
        {
            if(v != iterSource.front)
                return false;
            iterSource.popFront();
        }
        return true;
    }
}

/* Multidimensional not jagged array with dense storage.
   Static version (all dimensions are fixed) takes memory only for data.
 */
struct Arrax(T, params...)
{
    //TODO: Make ContainerType some copy-on-write type
    //TODO: Add trusted, nothrough, pure, etc
    //FIXME: Some members should be private
    static if(isValueOfTypeStrict!(bool, params[$-1]))
    {
        enum bool isTransposed = params[$-1];
        alias params[0..$-1] dimTuple;
    }
    else
    {
        enum bool isTransposed = false;
        alias params dimTuple;
    }
    
    static assert(isValueOfType!(size_t, dimTuple));
    static assert(all!("a >= 0")([dimTuple]));
    enum size_t[] dimPattern = [dimTuple];

    alias T ElementType;
    // Number of dimensions
    enum uint rank = dimPattern.length;
    // Number of dynamic dimensions
    enum uint rankDynamic = count(dimPattern, dynamicSize);
    // If the size of array is dynamic (i.e. at least one dimension is not defined)
    enum isDynamic = (rankDynamic > 0);

    // Array dimensions stride and data container type
    static if(isDynamic)
    {
        size_t[rank] _dim = dimPattern;
        size_t[rank] _stride;
        ElementType[] _container;
    }
    else
    {
        enum size_t[] _dim = dimPattern;
        enum size_t[] _stride = calcDenseStrides(_dim, isTransposed);
        ElementType[calcDenseContainerSize(_dim)] _container;
    }

    bool isCompatibleDimensions(in size_t[] dim) pure
    {
        if(dim.length != rank)
            return false;
        foreach(i, d; dim)
            if((d != dimPattern[i]) && (dimPattern[i] != dynamicSize))
                return false;
        return true;
    }

    // Leading dimension
    static if(dimPattern[0] != dynamicSize)
        enum size_t length = dimPattern[0];
    else
        size_t length() { return _dim[0]; }

    // Change dimensions
    static if(isDynamic)
    {
        /* Recalculate strides and reallocate container for current dimensions
         */
        private void _resize() pure
        {
            _stride = calcDenseStrides(_dim, isTransposed);
            _container.length = calcDenseContainerSize(_dim);
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
                assert(dim.length == rankDynamic);
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

    static if(isDynamic)
        // Convert ordinary 1D array to dense multidimensional array with given dimensions
        this(T[] source, size_t[] dim)
            in
            {
                assert(dim.length == rank);
                assert(source.length == reduce!("a * b")(dim));
                foreach(i, d; dimPattern)
                    if(d != dynamicSize)
                        assert(d == dim[i]);
            }
        body
        {
            _container = source;
            _dim = dim;
            _stride = calcDenseStrides(_dim, isTransposed);
        }
    else
        // Convert ordinary 1D array to static MD array with dense storage (no stride)
        this(T[] source)
            in
            {
                assert(source.length == reduce!("a * b")(_dim));
            }
        body
        {
            _container = source;
        }
    
    public // Slicing and indexing
    {
        // Auxiliary structure for slicing and indexing
        struct SliceProxy(size_t sliceRank, size_t depth)
        {
            // Type of the array that corresponds to the slicing result
            static if(sliceRank > 0)
                alias ArraxSlice!(T, sliceRank) EvalType;
            else
                alias T EvalType; // Slice is just set of indices
        
            //FIXME: dynamic array is not an optimal solution
            SliceBounds[] bounds;

            // Pointer to the array for which slice is calculated
            Arrax* source;

            this(Arrax* source_, SliceBounds[] bounds_)
            {
                source = source_;
                bounds = bounds_;
            }
        
            // Evaluate array for the slice
            EvalType eval()
            {
                static if(depth < rank)
                {
                    // If there is not enough bracket pairs - add empty []
                    static if(depth == rank - 1)
                        return this[];
                    else
                        return this[].eval();
                }
                else static if(sliceRank > 0)
                {
                    // Normal slice
                    auto foo = EvalType(*source, bounds);
                    return foo;
                }
                else
                {
                    // Set of indices
                    size_t index = 0; // Position in the container
                    foreach(i, b; bounds)
                        index += source._stride[i] * b.lo;
                    return source._container[index];
                }
            }

            alias eval this;

            // Slicing and indexing
            static if(depth < dimPattern.length - 1)
            {
                SliceProxy!(sliceRank, depth + 1) opSlice()
                {
                    return typeof(return)(source, bounds ~ SliceBounds(0, source._dim[depth]));
                }

                SliceProxy!(sliceRank, depth + 1) opSlice(size_t lo, size_t up)
                {
                    return typeof(return)(source, bounds ~ SliceBounds(lo, up));
                }

                SliceProxy!(sliceRank - 1, depth + 1) opIndex(size_t i)
                {
                    return typeof(return)(source, bounds ~ SliceBounds(i));
                }
            }
            else static if(depth == (dimPattern.length - 1))
            {
                // If only one more slicing can be done then return slice not proxy
                
                auto opSlice()
                {
                    return SliceProxy!(sliceRank, depth + 1)(
                        source, bounds ~ SliceBounds(0, source._dim[depth])).eval();
                }

                auto opSlice(size_t lo, size_t up)
                {
                    return SliceProxy!(sliceRank, depth + 1)(
                        source, bounds ~ SliceBounds(lo, up)).eval();
                }

                auto opIndex(size_t i)
                {
                    return SliceProxy!(sliceRank - 1, depth + 1)(
                        source, bounds ~ SliceBounds(i)).eval();
                }
            }

            MultArrayType!(ElementType, sliceRank) opCast()
            {
                return cast(MultArrayType!(ElementType, sliceRank))(eval());
            }
        
            auto opAssign(Tsource)(Tsource source)
            {
                return (eval() = source);
            }
        }

        // Slicing and indexing
        SliceProxy!(rank, 1) opSlice()
        {
            return typeof(return)(&this, [SliceBounds(0, _dim[0])]);
        }

        //ditto
        SliceProxy!(rank, 1) opSlice(size_t lo, size_t up)
        {
            return typeof(return)(&this, [SliceBounds(lo, up)]);
        }

        //ditto
        SliceProxy!(rank - 1, 1) opIndex(size_t i)
        {
            return typeof(return)(&this, [SliceBounds(i)]);
        }
    }

    public // Iterators
    {
        mixin IteratorByElementGeneric!(Arrax);
    }

    MultArrayType!(ElementType, rank) opCast()
    {
        return sliceToArray!(ElementType, rank)(_dim, _stride, _container);
    }
    
    ref Arrax opAssign(SourceType)(SourceType source)
        if(isArrayOrSlice!SourceType)
            in
            {
                assert(isCompatibleDimensions(source._dim));
            }
    body
    {
        static if(isDynamic)
            if(_dim != source._dim)
                setAllDimensions(source._dim);
        iteration.copy(source.byElement(), this.byElement());
        return this;
    }

    Arrax opUnary(string op)()
        if((op == "-") || (op == "+"))
    {
        Arrax result;
        static if(result.isDynamic)
            result.setAllDimensions(_dim);
        iteration.applyUnary!op(this.byElement(), result.byElement());
        return result;
    }
}

unittest // Type properties and dimensions
{
    static assert(Arrax!(int, 0).isDynamic);
    static assert(Arrax!(int, 1, 0).isDynamic);
    static assert(!(Arrax!(int, 1).isDynamic));
    static assert(!(Arrax!(int, 1, 2).isDynamic));

    static assert(Arrax!(int, 1, 0, true).isTransposed);
    static assert(!(Arrax!(int, 1).isTransposed));

    static assert(Arrax!(int, 1, 2)._dim == [1, 2]);
    static assert(Arrax!(int, 4, 2, 3)._stride == [6, 3, 1]);
    static assert(Arrax!(int, 1, 2).length == 1);
    static assert(Arrax!(int, 4, 2, 3, true)._stride == [1, 4, 8]);
    Arrax!(int, 1, 2, 0) a;
    assert(a.rank == 3);
    assert(a._dim == [1, 2, 0]);
    assert(a.length == 1);
    assert(a.isCompatibleDimensions([1, 2, 3]));
    assert(!(a.isCompatibleDimensions([1, 3, 3])));
    
    Arrax!(int, 0, 2) b;
    assert(b.length == 0);

    auto c = Arrax!(int, 0, 0, 0)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [2, 2, 3]);
    assert(c._container == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    assert(c._dim == [2, 2, 3]);
    assert(c._stride == [6, 3, 1]);
    auto d = ArraxSlice!(int, 2)([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [2, 3], [6, 2]);
    assert(d._container == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert(d._dim == [2, 3]);
    assert(d._stride == [6, 2]);

    Arrax!(int, 1, 2, 0, 3, 0, 4) a1;
    assert(a1.rank == 6);
    a1.setDimensions(5, 6);
    assert(a1._dim == [1, 2, 5, 3, 6, 4]);
    assert(a1._stride == [720, 360, 72, 24, 4, 1]);
    assert(a1._container.length == 720);
    a1.setAllDimensions([1, 2, 1, 3, 1, 4]);
    assert(a1._dim == [1, 2, 1, 3, 1, 4]);
    assert(a1._stride == [24, 12, 12, 4, 4, 1]);
    assert(a1._container.length == 24);
}

unittest // Slicing
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[1, 5, 9],
               [13, 17, 21]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[1, 2],
                [5, 6],
                [9, 10]],
               [[13, 14],
                [17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[][1][]
           == [[4, 5, 6, 7],
               [16, 17, 18, 19]]);
    assert(cast(int[]) a[][1][1]
           == [5, 17]);
    assert(cast(int[][]) a[][1][1..3]
           == [[5, 6],
               [17, 18]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[5, 9],
               [17, 21]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[5, 6],
                [9, 10]],
               [[17, 18],
                [21, 22]]]);
    assert(cast(int[][]) a[1][][]
           == [[12, 13, 14, 15],
               [16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][][1]
           == [13, 17, 21]);
    assert(cast(int[][]) a[1][][1..3]
           == [[13, 14],
               [17, 18],
               [21, 22]]);
    assert(cast(int[]) a[1][1][]
           == [16, 17, 18, 19]);
    assert(a[1][1][1] == 17);
    assert(cast(int[]) a[1][1][1..3]
           == [17, 18]);
    assert(cast(int[][]) a[1][1..3][]
           == [[16, 17, 18, 19],
               [20, 21, 22, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [17, 21]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[17, 18],
               [21, 22]]);
}

unittest // Slicing, transposed
{
    auto a = Arrax!(int, 2, 3, 4, true)(array(iota(0, 24)));
    assert(cast(int[][][]) a[][][]
           == [[[0, 6, 12, 18],
                [2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[1, 7, 13, 19],
                [3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][][1]
           == [[6, 8, 10],
               [7, 9, 11]]);
    assert(cast(int[][][]) a[][][1..3]
           == [[[6, 12],
                [8, 14],
                [10, 16]],
               [[7, 13],
                [9, 15],
                [11, 17]]]);
    
    assert(cast(int[][]) a[][1][]
           == [[2, 8, 14, 20],
               [3, 9, 15, 21]]);
    assert(cast(int[]) a[][1][1]
           == [8, 9]);
    assert(cast(int[][]) a[][1][1..3]
           == [[8, 14],
               [9, 15]]);
    assert(cast(int[][][]) a[][1..3][]
           == [[[2, 8, 14, 20],
                [4, 10, 16, 22]],
               [[3, 9, 15, 21],
                [5, 11, 17, 23]]]);
    assert(cast(int[][]) a[][1..3][1]
           == [[8, 10],
               [9, 11]]);
    assert(cast(int[][][]) a[][1..3][1..3]
           == [[[8, 14],
                [10, 16]],
               [[9, 15],
                [11, 17]]]);
    assert(cast(int[][]) a[1][][]
           == [[1, 7, 13, 19],
               [3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][][1]
           == [7, 9, 11]);
    assert(cast(int[][]) a[1][][1..3]
           == [[7, 13],
               [9, 15],
               [11, 17]]);
    assert(cast(int[]) a[1][1][]
           == [3, 9, 15, 21]);
    assert(a[1][1][1]
           == 9);
    assert(cast(int[]) a[1][1][1..3]
           == [9, 15]);
    assert(cast(int[][]) a[1][1..3][]
           == [[3, 9, 15, 21],
               [5, 11, 17, 23]]);
    assert(cast(int[]) a[1][1..3][1]
           == [9, 11]);
    assert(cast(int[][]) a[1][1..3][1..3]
           == [[9, 15],
               [11, 17]]);
}

unittest // Assignment
{
    alias Arrax!(int, 2, 3, 4) A;
    A a, b;
    a = A(array(iota(0, 24)));
    auto test = [[[0, 1, 2, 3],
                  [4, 5, 6, 7],
                  [8, 9, 10, 11]],
                 [[12, 13, 14, 15],
                  [16, 17, 18, 19],
                  [20, 21, 22, 23]]];
    assert(cast(int[][][])(b = a) == test);
    assert(cast(int[][][])b == test);
    alias Arrax!(int, 0, 3, 0) A1;
    A1 a1, b1;
    a1 = A1(array(iota(0, 24)), [2, 3, 4]);
    assert(cast(int[][][])(b1 = a1) == test);
    assert(cast(int[][][])b1 == test);
}

unittest // Assignment for slices
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(0, 24)));
    auto b = Arrax!(int, 2, 2, 2)(array(iota(24, 32)));
    auto c = a[][1..3][1..3];
    auto test = [[[0, 1, 2, 3],
                  [4, 24, 25, 7],
                  [8, 26, 27, 11]],
                 [[12, 13, 14, 15],
                  [16, 28, 29, 19],
                  [20, 30, 31, 23]]];
    assert(cast(int[][][]) (c = b) == cast(int[][][]) b);
    assert(cast(int[][][]) a == test);
}

unittest // Iterators
{
    // Normal
    {
        auto a = Arrax!(int, 2, 3, 4)(array(iota(24)));
        int[] test = array(iota(24));
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }

    // Transposed
    {
        auto a = Arrax!(int, 2, 3, 4, true)(array(iota(0, 24)));
        int[] test = [0, 6, 12, 18,
                      2, 8, 14, 20,
                      4, 10, 16, 22,
                      
                      1, 7, 13, 19,
                      3, 9, 15, 21,
                      5, 11, 17, 23];
        int[] result = [];
        foreach(v; a.byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Iterators for slice
{
    {
        auto a = Arrax!(int, 2, 3, 4)(array(iota(24)));
        int[] test = [5, 6,
                      9, 10,
                      
                      17, 18,
                      21, 22];
        int[] result = [];
        foreach(v; a[][1..3][1..3].byElement)
            result ~= v;
        assert(result == test);
    }
}

unittest // Unary operations 
{
    auto a = Arrax!(int, 2, 3, 4)(array(iota(24)));
    assert(cast(int[][][]) (+a)
           == [[[0, 1, 2, 3],
                [4, 5, 6, 7],
                [8, 9, 10, 11]],
               [[12, 13, 14, 15],
                [16, 17, 18, 19],
                [20, 21, 22, 23]]]);
    assert(cast(int[][][]) (-a)
           == [[[-0, -1, -2, -3],
                [-4, -5, -6, -7],
                [-8, -9, -10, -11]],
               [[-12, -13, -14, -15],
                [-16, -17, -18, -19],
                [-20, -21, -22, -23]]]);
}