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

import linalg.aux.traits;

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
    enum StorageOrder storageOrder = defaultStorageOrder;
    StorageRegular2D!(T) storage;

    ref auto opAssign(Tsource)(auto ref Tsource source) pure
    {
        copy(source.storage, this.storage);
        return this;
    }

    @property ref auto conj() pure
    {
        //FIXME: Will fail if conjugation changes type
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
