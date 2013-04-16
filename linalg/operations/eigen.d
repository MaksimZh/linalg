// Written in the D programming language.

/**
 * Low level implementation of matrix eigenvalue and eigenvector evaluation.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.eigen;

debug import linalg.debugging;

import linalg.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

/*
 * Bindings for eigenproblems
 */
private version(linalg_backend_lapack)
{
    import linalg.backends.lapack;

    alias linalg.backends.lapack.symmEigenval symmEigenval;
}

/*
 * Return all eigenvalues.
 *
 * Only upper-triangle part is used.
 * Contents of storage will be modified.
 */
auto matrixSymmEigenval(Tsource)(ref Tsource source) pure
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

    return symmEigenval(source.container, source.nrows);
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

    return symmEigenval(source.container, source.nrows, ilo, iup);
}
