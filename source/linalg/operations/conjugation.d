// Written in the D programming language.

/**
 * Low level implementation of matrix conjugation and transposition.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.conjugation;

debug import linalg.aux.debugging;

import linalg.aux.types;
import linalg.aux.traits;
import linalg.operations.basic;

/* Hermitian conjugation of vector */
void conjMatrix(Tsource, Tdest)(
    auto ref Tsource source, auto ref Tdest dest) pure
    if(isStorage!Tsource && isStorage!Tdest)
    in
    {
        static if(Tsource.rank == 1)
            assert(dest.dim == source.dim);
        else static if(Tsource.rank == 2)
            assert(dest.nrows == source.ncols && dest.ncols == source.nrows);
    }
body
{
    static assert(Tsource.rank == Tdest.rank,
                  "Cannot copy conjugated elements"
                  "between storages of different rank");
    debug(linalg_operations) dfoOp2("conjMatrix",
                                    source.container, dest.container);
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
