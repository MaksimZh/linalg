// Written in the D programming language.

module linalg.storage.operations;

debug import std.stdio;

import linalg.storage.dense2d;

void copy(Tsource, Tdest)(const ref Tsource source, ref Tdest dest) pure
    if(isStorageDense2D!Tsource && isStorageDense2D!Tdest)
    in
    {
        assert(dest.isCompatDim(source.dim));
    }
body
{
}
