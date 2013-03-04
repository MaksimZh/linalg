// Written in the D programming language.

module linalg.storage.operations;

debug import std.stdio;

import linalg.storage.dense2d;

void copy(Tsource, Tdest)(ref Tsource source, ref Tdest dest) pure
    if(is2DStorageOrView!Tsource && is2DStorageOrView!Tdest)
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    static if(is2DView!Tdest)
    {
        debug(copy) writeln("copy to view");
        dest.onChange();
        copy2D(source.container.array, source.stride,
               dest.container.array, dest.stride, dest.dim);
    }
    else
    {
        static if(dest.isStatic)
        {
            debug(copy) writeln("copy to static");
            copy2D(source.container.array, source.stride,
                   dest.container.array, dest.stride, dest.dim);
        }
        else
        {
            debug(copy) writeln("copy to dynamic");
            dest.onReset();
            source.onShare();
            dest.container = source.container[];
            dest.dim = source.dim;
            dest.stride = source.stride;
        }
    }
}
