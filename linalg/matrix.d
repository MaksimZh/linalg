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

import linalg.storage.regular2d;
import linalg.aux.traits;

void copy(Tsource, Tdest)(auto ref Tsource source,
                          auto ref Tdest dest) pure
{
    
    static assert(isExistOp!(Tdest.ElementType, "=", Tsource.ElementType),
                  "Cannot copy (" ~ Tsource.ElementType.stringof
                  ~ ") to (" ~ Tdest.ElementType.stringof ~ ")");
    auto isource = source.byElement;
    auto idest = dest.byElement;
    while(!(isource.empty))
    {
        idest.front = isource.front;
        isource.popFront();
        idest.popFront();
    }
}

void conjMatrix(Tsource, Tdest)(
    auto ref Tsource source, auto ref Tdest dest) pure
{
    static if(Tsource.rank == 1)
    {
        static if(isComplex!(Tsource.ElementType))
            map!("a.conj")(source, dest);
        else
            copy(source, dest);
    }
    else static if(Tsource.rank == 2)
    {
        auto isource = source.byRow();
        auto idest = dest.byCol();
        while(!(isource.empty))
        {
            conjMatrix(isource.front, idest.front);
            isource.popFront();
            idest.popFront();
        }
    }
}

struct BasicMatrix(T)
{
    enum size_t nrows_ = 2;
    enum size_t ncols_ = 2;

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
        conjMatrix(this.storage, dest.storage);
        return dest;
    }
}

struct Foo
{
    BasicMatrix!(int) coeffs;
}

alias BasicMatrix!(Foo) XXX;
