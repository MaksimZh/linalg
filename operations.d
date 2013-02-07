// Written in the D programming language.

/** Perform arithmetic and other operations on storages.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.operations;

import linalg.storage;

debug import std.stdio;

bool compare(Tsource, Tdest)(ref Tsource source, ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
{
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        if(d != isource.front)
            return false;
        isource.popFront();
    }
    return true;
}

void copy(Tsource, Tdest)(ref Tsource source, ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
        in
        {
            assert(dest.isCompatibleDimensions(source.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source);
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
}

void applyUnary(string op, Tsource, Tdest)(ref Tsource source, ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
        in
        {
            assert(dest.isCompatibleDimensions(source.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source);
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = mixin(op ~ "isource.front");
        isource.popFront();
    }
}

void applyBinary(string op, Tsource1, Tsource2, Tdest)(ref Tsource1 source1,
                                                       ref Tsource2 source2,
                                                       ref Tdest dest)
    if(isStorage!Tsource1 && isStorage!Tsource2 && isStorage!Tdest)
        in
        {
            assert(source1.dimensions == source2.dimensions);
            assert(dest.isCompatibleDimensions(source1.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source1);
    auto isource1 = source1.byElement;
    auto isource2 = source2.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = mixin("isource1.front" ~ op ~ "isource2.front");
        isource1.popFront();
        isource2.popFront();
    }
}

void matrixMult(Tsource1, Tsource2, Tdest)(ref Tsource1 source1,
                                           ref Tsource2 source2,
                                           ref Tdest dest)
    if(isStorage!Tsource1 && isStorage!Tsource2 && isStorage!Tdest)
        in
        {
            assert(source1.dimensions[1] == source2.dimensions[0]);
            assert(dest.isCompatibleDimensions([source1.dimensions[0], source2.dimensions[1]]));
        }
body
{
    //FIXME: probably this is the ugliest implementation of matrix multiplication ever
    static if(dest.isResizeable)
        dest.setAllDimensions([source1.dimensions[0], source2.dimensions[1]]);
    auto idest = dest.byElement;
    foreach(row; source1.byRow)
        foreach(col; source2.byCol)
        {
            auto irow = row.byElement;
            auto icol = col.byElement;
            /* Can not just write front = 0 in generic code. */
            idest.front = irow.front * icol.front;
            irow.popFront();
            icol.popFront();
            while(!(irow.empty))
            {
                idest.front += irow.front * icol.front;
                irow.popFront();
                icol.popFront();
            }
            idest.popFront();
        }
}
