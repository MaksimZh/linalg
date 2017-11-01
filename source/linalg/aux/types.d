// Written in the D programming language.

/**
 * This module contains types and constants used by all parts of the library.
 *
 * Some of this staff should probably be moved somewhere else.
 *
 *  Authors:    Maksim Sergeevich Zholudev
 *  Copyright:  Copyright (c) 2013, Maksim Zholudev
 *  License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.aux.types;

import std.traits;

/** Value to denote not fixed dimension of the array */
enum size_t dynsize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    row, /// 000, 001, 002, ..., 010, 011, ...
    col  /// 000, 100, 200, ..., 010, 110, ...
}

/** Storage order that is set by default */
enum StorageOrder defaultStorageOrder = StorageOrder.row;

/* Unary pure function with const argument */
template safeUnaryFun(alias fun)
{
    static if (is(typeof(fun) : string))
    {
        auto safeUnaryFun(ElementType)(auto ref ElementType a) pure
        {
            mixin("return (" ~ fun ~ ");");
        }
    }
    else
    {
        alias fun safeUnaryFun;
    }
}

/* Binary pure function with const arguments */
template safeBinaryFun(alias fun)
{
    static if (is(typeof(fun) : string))
    {
        auto safeBinaryFun(ElementTypeA, ElementTypeB)(
            auto ref ElementTypeA a,
            auto ref ElementTypeB b) pure
        {
            mixin("return (" ~ fun ~ ");");
        }
    }
    else
    {
        alias fun safeBinaryFun;
    }
}

/* Derive return type of unary function that can be given as string */
template ReturnTypeOfUnaryFun(alias fun, ArgumentType)
{
    alias ReturnType!((ArgumentType a) => safeUnaryFun!fun(a))
        ReturnTypeOfUnaryFun;
}

/* Detect whether T is a complex type
 * i.e. whether it has conj property
 */
template isComplex(T)
{
    enum bool isComplex = is(typeof((T a) => a.conj));
}

unittest
{
    static assert(isComplex!(Complex!double));
    static assert(!(isComplex!int));
}

//HACK: needed to get .conj property
public import std.complex;
@property auto conj(T)(Complex!T z) @safe pure nothrow
{
    return std.complex.conj(z);
}

template zero(T)
{
    static if(isNumeric!T)
        enum T zero = 0;
    else static if(isComplex!T && is(typeof(T(0, 0))))
        enum T zero = T(0, 0);
    else static if(is(typeof(T.zero) == T))
        enum T zero = T.zero;
    else static if(is(typeof(T.zero()) == T))
        enum T zero = T.zero();
    else static assert(false, "Can't find zero for " ~ T.stringof);
}

/** Input range with elements constructed from the elements of the wrapped one */
struct InputRangeWrapper(RangeType, NewElementType)
{
    private RangeType range;
    
    this(RangeType range) pure { this.range = range; }

    @property bool empty() pure  { return range.empty; }
    @property auto ref NewElementType front() pure {
        return NewElementType(range.front); }
    void popFront() pure { range.popFront; }
}

/**
 * Memory management of matrix, vector or array
 */
enum MemoryManag
{
    stat,
    bound,
    dynamic
}
