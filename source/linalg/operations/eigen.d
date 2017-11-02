// Written in the D programming language.

/**
 * Low level implementation of matrix eigenvalue and eigenvector evaluation.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.eigen;

debug import linalg.misc.debugging;

import linalg.misc.types;
import linalg.storage.regular1d;
import linalg.storage.regular2d;

/*
 * Bindings for eigenproblems
 */
private version(linalg_backend_lapack)
{
    import linalg.backends.lapack;

    alias linalg.backends.lapack.symmEigenval symmEigenval;
    alias linalg.backends.lapack.symmEigenAll symmEigenAll;
}
private version(linalg_backend_mkl)
{
    import linalg.backends.mkl;

    alias linalg.backends.mkl.symmEigenval symmEigenval;
    alias linalg.backends.mkl.symmEigenAll symmEigenAll;
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
    debug(linalg_operations) dfoOp1("eigenval",
                                    source.container);
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
    debug(linalg_operations) dfoOp1("eigenval",
                                    source.container);
    return symmEigenval(source.container, source.nrows, ilo, iup);
}

/*
 * Return eigenvalues in given range
 * and corresponding eigenvectors.
 *
 * Only upper-triangle part is used.
 * Contents of storage will be modified.
 */
auto matrixSymmEigenAll(Tsource)(ref Tsource source,
                                 size_t ilo, size_t iup) pure
    if(isStorageRegular2D!Tsource)
        in
        {
            assert(source.nrows == source.ncols);
        }
body
{
    debug(linalg_operations) dfoOp1("eigenval",
                                    source.container);
    return symmEigenAll(source.container, source.nrows, ilo, iup);
}
