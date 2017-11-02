// Written in the D programming language.

/**
 * Traits.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.misc.traits;

import std.traits;

public import oddsends;
import linalg.misc.types;

template isExistFun(ResultType, alias fun, Targs...)
{
    enum isExistFun =
        isExistOp!(ResultType, "=",
                   ReturnType!((Targs args) => fun(args)));
}

template isStorage(T)
{
    static if(hasMember!(T, "dimPattern")
              && hasMember!(T, "ElementType")
              && hasMember!(T, "rank")
              && hasMember!(T, "isStatic")
              && hasMember!(T, "isCompatDim")
              && hasMember!(T, "byElement"))
    {
        enum isStorage =
            (is(typeof(T.dimPattern) == size_t[])
             || is(typeof(T.dimPattern) == size_t))
            && isTypeTuple!((T.ElementType))
            && is(typeof(T.rank) == uint)
            && is(typeof(T.isStatic) == bool)
            && (T.isStatic || hasMember!(T, "setDim"));
    }
    else
    {
        enum isStorage = false;
    }
}

template isStorageOfRank(uint rank, T)
{
    static if(isStorage!T)
        enum isStorageOfRank = (T.rank == rank);
    else
        enum isStorageOfRank = false;
}
