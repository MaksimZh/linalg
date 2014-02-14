// Written in the D programming language.

/**
 * Array <-> Matrix conversion
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013-2014, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.meta;

public import linalg.array;
public import linalg.matrix;
import std.stdio;

@property auto array(Tsource)(auto ref Tsource source)
    if(isMatrix!Tsource && !(Tsource.isVector))
{
    alias ArrayView2D!(Tsource.ElementType, dynsize, dynsize,
                       Tsource.storageOrder) Tresult;
    return Tresult(Tresult.StorageType(source.storage));
}

@property auto matrix(Tsource)(auto ref Tsource source)
    if(isArray2D!Tsource)
{
    alias MatrixView!(Tsource.ElementType, dynsize, dynsize,
                      Tsource.storageOrder) Tresult;
    return Tresult(Tresult.StorageType(source.storage));
}

unittest
{
    int[] a = [1, 2, 3, 4, 5, 6];

    auto b = Matrix!(int, 2, 3)(a);
    auto c = Array2D!(int, 2, 3)(a);
    assert(cast(int[][]) b.array == [[1, 2, 3],
                                     [4, 5, 6]]);
    assert(cast(int[][]) c.matrix == [[1, 2, 3],
                                      [4, 5, 6]]);
    assert(cast(int[][]) (Matrix!(int, dynsize, dynsize)(a, 2, 3)).array
           == [[1, 2, 3],
               [4, 5, 6]]);
    assert(cast(int[][]) (Array2D!(int, dynsize, dynsize)(a, 2, 3)).matrix
           == [[1, 2, 3],
               [4, 5, 6]]);
    auto mx = Matrix!(int, 2, 2)([1, 2,
                                  3, 4]);
    auto mxx = mx.array * mx;
    assert(cast(int[][]) mxx[0, 0] == [[1, 2],
                                       [3, 4]]);
    assert(cast(int[][]) mxx[0, 1] == [[2, 4],
                                       [6, 8]]);
    assert(cast(int[][]) mxx[1, 0] == [[3, 6],
                                       [9, 12]]);
    assert(cast(int[][]) mxx[1, 1] == [[4, 8],
                                       [12, 16]]);
}
