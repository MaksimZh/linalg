// Written in the D programming language.

module linalg.storage.operations;

debug import linalg.debugging;

import linalg.storage.regular1d;
import linalg.storage.regular2d;

void copy(Tsource, Tdest)(const ref Tsource source, ref Tdest dest) pure
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
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
}
