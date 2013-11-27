// Written in the D programming language.

/**
 * Low level implementation of matrix conjugation and transposition.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.conjugation;

debug import linalg.debugging;

import linalg.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;
import linalg.operations.basic;

/* Hermitian conjugation of vector */
void conjMatrix(Tsource, Tdest)(
    auto ref Tsource source, auto ref Tdest dest) pure
    if(isStorageRegular1D!Tsource && isStorageRegular1D!Tdest)
    in
    {
        assert(dest.length == source.length);
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.conjMatrix()");
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

    static if(isComplex!(Tsource.ElementType))
        map!("a.conj")(source, dest);
    else
        copy(source, dest);
}

/* Hermitian conjugation */
void conjMatrix(Tsource, Tdest)(
    auto ref Tsource source, auto ref Tdest dest) pure
    if(isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
    in
    {
        assert(dest.nrows == source.ncols && dest.ncols == source.nrows);
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.conjMatrix()");
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

    auto isource = source.byRow();
    auto idest = dest.byCol();
    while(!(isource.empty))
    {
        conjMatrix(isource.front, idest.front);
        isource.popFront();
        idest.popFront();
    }
}
