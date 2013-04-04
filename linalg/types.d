// Written in the D programming language.

module linalg.types;

import std.traits;

/** Value to denote not fixed dimension of the array */
enum size_t dynamicSize = 0;

/** Order of the elements in the container */
enum StorageOrder
{
    rowMajor, /// 000, 001, 002, ..., 010, 011, ...
    colMajor  /// 000, 100, 200, ..., 010, 110, ...
}

enum StorageOrder defaultStorageOrder = StorageOrder.rowMajor;

template TypeOfOp(Tlhs, string op, Trhs)
{
    alias ReturnType!((Tlhs lhs, Trhs rhs) => mixin("lhs"~op~"rhs"))
        TypeOfOp;
}

/* Unary pure function with const argument */
template safeUnaryFun(alias fun)
{
    static if (is(typeof(fun) : string))
    {
        auto safeUnaryFun(ElementType)(auto ref const ElementType a) pure
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
            auto ref const ElementTypeA a,
            auto ref const ElementTypeB b) pure
        {
            mixin("return (" ~ fun ~ ");");
        }
    }
    else
    {
        alias fun safeBinaryFun;
    }
}

template ReturnTypeOfUnaryFun(alias fun, ArgumentType)
{
    alias ReturnType!((ArgumentType a) => safeUnaryFun!fun(a))
        ReturnTypeOfUnaryFun;
}

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
