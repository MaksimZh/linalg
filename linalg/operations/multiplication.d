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
import linalg.traits;

/*
 * Matrix multiplication
 * row * column
 */
auto mulRowCol(TsourceA, TsourceB)(
    ref TsourceA sourceA,
    ref TsourceB sourceB) pure
    if(isStorageOfRank!(1, TsourceA) && isStorageOfRank!(1, TsourceB))
    in
    {
        assert(sourceA.length == sourceB.length);
    }
body
{
    debug(linalg_operations) dfoOp2("row*col",
                                    sourceA.container,
                                    sourceB.container);
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
 * column * row
 */
void mulColRow(TsourceA, TsourceB, Tdest)(
    ref TsourceA sourceA,
    ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageOfRank!(1, TsourceA) && isStorageOfRank!(1, TsourceB)
       && isStorageOfRank!(2, Tdest))
    in
    {
        assert(dest.nrows == sourceA.length);
        assert(dest.ncols == sourceB.length);
    }
body
{
    debug(linalg_operations) dfoOp2("col*row",
                                    sourceA.container,
                                    sourceB.container);
    auto idest = dest.byElement;
    foreach(ref a; sourceA.byElement)
        foreach(ref b; sourceB.byElement)
        {
            idest.front = a * b;
            idest.popFront;
        }
}

/*
 * Matrix multiplication
 * matrix * column
 */
void mulMatCol(TsourceA, TsourceB, Tdest)(
    ref TsourceA sourceA,
    ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageOfRank!(2, TsourceA) && isStorageOfRank!(1, TsourceB)
       && isStorageOfRank!(1, Tdest))
    in
    {
        assert(sourceA.ncols == sourceB.length);
        assert(dest.length == sourceA.nrows);
    }
body
{
    debug(linalg_operations) dfoOp2("mat*col",
                                    sourceA.container,
                                    sourceB.container);
    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
    {
        idest.front = mulRowCol(rowA, sourceB);
        idest.popFront;
    }
}

/*
 * Matrix multiplication
 * row * matrix
 */
void mulRowMat(TsourceA, TsourceB, Tdest)(
    ref TsourceA sourceA,
    ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageOfRank!(1, TsourceA) && isStorageOfRank!(2, TsourceB)
       && isStorageOfRank!(1, Tdest))
    in
    {
        assert(sourceA.length == sourceB.nrows);
        assert(dest.length == sourceB.ncols);
    }
body
{
    debug(linalg_operations) dfoOp2("row*mat",
                                    sourceA.container,
                                    sourceB.container);
    auto idest = dest.byElement;
    foreach(colB; sourceB.byCol)
    {
        idest.front = mulRowCol(sourceA, colB);
        idest.popFront;
    }
}

/*
 * Matrix multiplication
 * matrix * matrix
 */
void mulMatMat(TsourceA, TsourceB, Tdest)(
    ref TsourceA sourceA,
    ref TsourceB sourceB,
    ref Tdest dest) pure
    if(isStorageOfRank!(2, TsourceA) && isStorageOfRank!(2, TsourceB)
       && isStorageOfRank!(2, Tdest))
    in
    {
        assert(sourceA.ncols == sourceB.nrows);
        assert(dest.nrows == sourceA.nrows);
        assert(dest.ncols == sourceB.ncols);
    }
body
{
    debug(linalg_operations) dfoOp2("mat*mat",
                                    sourceA.container,
                                    sourceB.container);
    auto idest = dest.byElement;
    foreach(rowA; sourceA.byRow)
        foreach(colB; sourceB.byCol)
        {
            idest.front = mulRowCol(rowA, colB);
            idest.popFront;
        }
}
