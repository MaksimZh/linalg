// Written in the D programming language.

/**
 * Low level implementation of matrix multiplication.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.multiplication;

debug import linalg.debugging;

import linalg.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

/*
 * Matrix multiplication
 * row * column
 */
auto mulAsMatrices(TsourceA, TsourceB)(
     ref TsourceA sourceA,
     ref TsourceB sourceB) pure
    if(isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB)
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                        sourceA.container.ptr,
                        sourceA.container.length);
        debugOP.writefln("from <%X>, %d",
                        sourceB.container.ptr,
                        sourceB.container.length);
        debugOP.writefln("to   return");
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    auto result = isourceA.front * isourceB.front;
    isourceA.popFront();
    isourceB.popFront();
    while(!(isourceA.empty))
    {
        result += isourceA.front * isourceB.front;
        isourceA.popFront();
        isourceB.popFront();
    }
    return result;
}

/*
 * Matrix multiplication
 * matrix * column
 */
void mulAsMatrices(TsourceA, TsourceB, Tdest)(
     ref TsourceA sourceA,
     ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular2D!TsourceA && isStorageRegular1D!TsourceB
       && isStorageRegular1D!Tdest)
        in
        {
            assert(sourceA.ncols == sourceB.length);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
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

    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
    {
        idest.front = mulAsMatrices(rowA, sourceB);
        idest.popFront;
    }
}

/*
 * Matrix multiplication
 * row * matrix
 */
void mulAsMatrices(TsourceA, TsourceB, Tdest)(
     ref TsourceA sourceA,
     ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular1D!TsourceA && isStorageRegular2D!TsourceB
       && isStorageRegular1D!Tdest)
        in
        {
            assert(sourceA.length == sourceB.nrows);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
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

    auto idest = dest.byElement;
    foreach(colB; sourceB.byCol)
    {
        idest.front = mulAsMatrices(sourceA, colB);
        idest.popFront;
    }
}

/*
 * Matrix multiplication
 * matrix * matrix
 */
void mulAsMatrices(TsourceA, TsourceB, Tdest)(
     ref TsourceA sourceA,
     ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB
       && isStorageRegular2D!Tdest)
        in
        {
            assert(sourceA.ncols == sourceB.nrows);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.mulAsMatrices()");
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

    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
        foreach(colB; sourceB.byCol)
        {
            idest.front = mulAsMatrices(rowA, colB);
            idest.popFront;
        }
}
