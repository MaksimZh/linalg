// Written in the D programming language.

/**
 * Low level implementation of matrix operations.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.storage.operations;

debug import linalg.debugging;

import linalg.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

/* Copy data between storages */
void copy(Tsource, Tdest)(const auto ref Tsource source,
                          auto ref Tdest dest) pure
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
    while(!(isource.empty))
    {
        idest.front = isource.front;
        isource.popFront();
        idest.popFront();
    }
}

/* Copy data between storages applying function */
void map(alias fun, Tsource, Tdest)(const auto ref Tsource source,
                                    auto ref Tdest dest) pure
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
        debugOP.writefln("operations.map()");
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
    alias safeUnaryFun!fun funToApply;
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isource.front);
        isource.popFront();
    }
}

/* Copy data between storages applying function (impure version) */
void mapImp(alias fun, Tsource, Tdest)(const auto ref Tsource source,
                                       auto ref Tdest dest)
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
        debugOP.writefln("operations.mapImp()");
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
    alias safeUnaryFun!fun funToApply;
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isource.front);
        isource.popFront();
    }
}

/*
 * Copy data between storages applying function with arbitrary number
 * of arguments
 */
void mapArgs(alias fun, Tsource, Tdest, Targs...)(
    const auto ref Tsource source,
    auto ref Tdest dest,
    const auto ref Targs args) pure
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
        debugOP.writefln("operations.mapArgs()");
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
    alias fun funToApply;
    auto isource = source.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isource.front, args);
        isource.popFront();
    }
}

/*
 * Merge data from two storages using binary function
 * and copy it to the third storage
 */
void zip(alias fun, TsourceA, TsourceB, Tdest)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
    ref Tdest dest) pure
    if((isStorageRegular2D!TsourceA && isStorageRegular2D!TsourceB
        && isStorageRegular2D!Tdest)
       || (isStorageRegular1D!TsourceA && isStorageRegular1D!TsourceB
           && isStorageRegular1D!Tdest))
    in
    {
        assert(dest.isCompatDim(sourceA.dim));
        assert(sourceA.dim == sourceB.dim);
    }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.zip()");
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
    alias safeBinaryFun!fun funToApply;
    auto isourceA = sourceA.byElement;
    auto isourceB = sourceB.byElement;
    auto idest = dest.byElement;
    foreach(ref d; idest)
    {
        d = funToApply(isourceA.front, isourceB.front);
        isourceA.popFront();
        isourceB.popFront();
    }
}

/* Hermitian conjugation of vector */
void conjMatrix(Tsource, Tdest)(
    const ref Tsource source, ref Tdest dest) pure
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
    const ref Tsource source, ref Tdest dest) pure
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

    auto isource = source.byRow;
    auto idest = dest.byCol;
    while(!(isource.empty))
    {
        static if(isComplex!(Tsource.ElementType))
            map!("a.conj")(isource.front, idest.front);
        else
            copy(isource.front, idest.front);
        isource.popFront();
        idest.popFront();
    }
}

/*
 * Matrix multiplication
 * row * column
 */
auto mulAsMatrices(TsourceA, TsourceB)(
    const ref TsourceA sourceA,
    const ref TsourceB sourceB) pure
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
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
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
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
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
    const ref TsourceA sourceA,
    const ref TsourceB sourceB,
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

/*
 * Bindings for eigenproblems
 */
private version(linalg_backend_lapack)
{
    import linalg.backends.lapack;

    alias linalg.backends.lapack.symmEigenval symmEigenval;
}

/*
 * Return eigenvalues in given range
 * (ascending order, starts from 0, includes borders).
 *
 * Only upper-triangle part is used.
 * Contents of storage will be modified.
 */
auto matrixSymmEigenval(Tsource)(ref Tsource source,
                                 size_t ilo, size_t iup) pure
    if(isStorageRegular2D!Tsource)
        in
        {
            assert(source.nrows == source.ncols);
        }
body
{
    debug(operations)
    {
        debugOP.writefln("operations.matrixSymmEigenval()");
        mixin(debugIndentScope);
        debugOP.writefln("from <%X>, %d",
                         source.container.ptr,
                         source.container.length);
        debugOP.writeln("...");
        mixin(debugIndentScope);
    }

    return symmEigenval(source.data, source.nrows, ilo, iup);
}
