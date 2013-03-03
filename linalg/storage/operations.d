// Written in the D programming language.

module linalg.storage.operations;

debug import std.stdio;

import linalg.storage.dense2d;

void copy(Tsource, Tdest)(in Tsource source, ref Tdest dest) pure
    if(is2DStorageOrView!Tsource && is2DStorageOrView!Tdest)
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
    static if(dest.isResizeable)
        dest.setDim(source.dim);
    copy2D(source.container.array, source.stride,
           dest.container.array, dest.stride, dest.dim);
}
