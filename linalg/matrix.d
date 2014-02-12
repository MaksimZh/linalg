// Written in the D programming language.

/**
 * Matrices.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.matrix;

import std.traits;

/** Derive type of the result of binary operation */
template TypeOfOp(Tlhs, string op, Trhs)
{
    alias ReturnType!((Tlhs lhs, Trhs rhs) => mixin("lhs"~op~"rhs"))
        TypeOfOp;
}

/** Test whether binary operation exists for given operand types */
template isExistOp(Tlhs, string op, Trhs)
{
    enum isExistOp = is(TypeOfOp!(Tlhs, op, Trhs));
}

void copy(Tsource, Tdest)(auto ref Tsource source,
                          auto ref Tdest dest) pure
{
    
    static assert(isExistOp!(Tdest.ElementType, "=", Tsource.ElementType),
                  "Cannot copy (" ~ Tsource.ElementType.stringof
                  ~ ") to (" ~ Tdest.ElementType.stringof ~ ")");
}

struct StorageRegular2D(T)
{
    alias T ElementType;
    public enum uint rank = 2;
}

struct BasicMatrix(T)
{
    StorageRegular2D!(T) storage;

    ref auto opAssign(Tsource)(auto ref Tsource source)
    {
        copy(source.storage, this.storage);
        return this;
    }

    ref auto conj()
    {
        BasicMatrix!(T) dest;
        copy(this.storage, dest.storage);
        return dest;
    }
}

struct Foo
{
    BasicMatrix!(int) coeffs;
}

alias BasicMatrix!(Foo) XXX;
