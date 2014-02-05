// Written in the D programming language.

/**
 * Low level implementation of matrix operations that are based on single
 * scan of all the elements.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.basic;

debug import linalg.debugging;

import linalg.types;
import linalg.traits;

/* Copy data between storages */
void fill(Tvalue, Tdest)(auto ref Tvalue value,
                         auto ref Tdest dest) pure
    if(isStorage!Tdest)
{
    static assert(isExistOp!(Tdest.ElementType, "=", Tvalue),
                  "Cannot fill storage of (" ~ Tdest.ElementType.stringof
                  ~ ") with (" ~ Tvalue.stringof ~ ")");
    debug(linalg_operations) dfoOp1("fill", dest.container);
    auto idest = dest.byElement;
    while(!(idest.empty))
    {
        idest.front = value;
        idest.popFront();
    }
}

/* Compare two storages */
bool compare(TsourceA, TsourceB)(auto ref TsourceA sourceA,
                                 auto ref TsourceB sourceB) pure
    if(isStorage!TsourceA && isStorage!TsourceB)
{
    static assert(TsourceA.rank == TsourceB.rank,
                  "Cannot compare storages of different rank");
    static assert(isExistOp!(TsourceA.ElementType, "==", TsourceB.ElementType),
                  "Cannot compare (" ~ TsourceA.ElementType
                  ~ ") and (" ~ TsourceB.ElementType ~ ")");
    debug(linalg_operations) dfoOp2("compare",
                                    sourceA.container,
                                    sourceB.container);
    if(sourceA.dim != sourceB.dim)
        return false;
    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    while(!(isourceA.empty))
    {
        if(isourceA.front != isourceB.front)
            return false;
        isourceA.popFront();
        isourceB.popFront();
    }
    return true;
}

/* Copy data between storages */
void copy(Tsource, Tdest)(auto ref Tsource source,
                          auto ref Tdest dest) pure
    if(isStorage!Tsource && isStorage!Tdest)
    in
    {
        assert(dest.isCompatDim(source.dim), "Incompatible ");
    }
body
{
    static assert(Tsource.rank == Tdest.rank,
                  "Cannot copy elements between storages of different rank");
    static assert(isExistOp!(Tdest.ElementType, "=", Tsource.ElementType),
                  "Cannot copy (" ~ Tsource.ElementType.stringof
                  ~ ") to (" ~ Tdest.ElementType.stringof ~ ")");
    debug(linalg_operations) dfoOp2("copy", source.container, dest.container);
    auto isource = source.byElement;
    auto idest = dest.byElement;
    while(!(isource.empty))
    {
        idest.front = isource.front;
        isource.popFront();
        idest.popFront();
    }
}

/*
 * Copy data between storages applying function with arbitrary number
 * of arguments
 */
void map(alias fun, Tsource, Tdest, Targs...)(
    auto ref Tsource source,
    auto ref Tdest dest,
    auto ref Targs args) pure
    if(isStorage!Tsource && isStorage!Tdest)
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    static assert(Tsource.rank == Tdest.rank,
                  "Cannot map function between storages of different rank");
    static if(Targs.length == 0)
        alias safeUnaryFun!fun funToApply;
    else
        alias fun funToApply;
    static assert(isExistFun!(Tdest.ElementType, funToApply,
                              Tsource.ElementType, Targs),
                  "Cannot map (" ~ Tsource.ElementType.stringof
                  ~ ", " ~ Targs.length ~ " arguments) -> ("
                  ~ Tdest.ElementType.stringof
                  ~ "): band function or storage element types");
    
    debug(linalg_operations) dfoOp2("map", source.container, dest.container);
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        static if(Targs.length == 0)
            d = funToApply(isource.front);
        else
            d = funToApply(isource.front, args);

        isource.popFront();
    }
}

/*
 * Merge data from two storages using binary function
 * and copy it to the third storage
 */
void zip(alias fun, TsourceA, TsourceB, Tdest)(
    ref TsourceA sourceA,
    ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorage!TsourceA && isStorage!TsourceB && isStorage!Tdest)
    in
    {
        assert(dest.isCompatDim(sourceA.dim));
        assert(sourceA.dim == sourceB.dim);
    }
body
{
    static assert(TsourceA.rank == Tdest.rank && TsourceB.rank == Tdest.rank,
                  "Cannot zip storages of different rank");
    alias safeBinaryFun!fun funToApply;
    static assert(isExistFun!(Tdest.ElementType, funToApply,
                              TsourceA.ElementType, TsourceB.ElementType),
                  "Cannot zip (" ~ TsourceA.ElementType.stringof
                  ~ ", " ~ TsourceB.ElementType.stringof ~ ") -> ("
                  ~ Tdest.ElementType.stringof
                  ~ "): band function or storage element types");

    debug(linalg_operations) dfoOp3("zip",
                                    sourceA.container, sourceB.container,
                                    dest.container);
    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isourceA.front, isourceB.front);
        isourceA.popFront();
        isourceB.popFront();
    }
}
