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
import linalg.storage.regular1d;
import linalg.storage.regular2d;

/* Copy data between storages */
void fill(Tvalue, Tdest)(auto ref Tvalue value,
                         auto ref Tdest dest) pure
    if((isStorageRegular2D!Tdest || isStorageRegular1D!Tdest)
       && is(Tvalue == Tdest.ElementType))
{
    debug(operations)
    {
        debugOP.writefln("operations.fill()");
        mixin(debugIndentScope);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
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
    if((isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB)
       || (isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB))
{
    debug(operations)
    {
        debugOP.writefln("operations.compare()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
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
    if((isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
       || (isStorageRegular1D!Tsource && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.copy()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        source.container.ptr,
                        source.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
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
    if((isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
       || (isStorageRegular1D!Tsource && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.map()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        source.container.ptr,
                        source.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
    auto isource = source.byElement;
    auto idest = dest.byElement;

    static if(Targs.length == 0)
        alias safeUnaryFun!fun funToApply;
    else
        alias fun funToApply;

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
    if((isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB
        && isStorageRegular2D!Tdest)
       || (isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB
           && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(sourceA.dim));
        assert(sourceA.dim == sourceB.dim);
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.zip()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   <%X>, %d",
                        dest.container.ptr,
                        dest.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }
    alias safeBinaryFun!fun funToApply;
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
