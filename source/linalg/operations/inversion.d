// Written in the D programming language.

/**
 * Low level implementation of matrix inversion.
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.operations.inversion;

debug import linalg.misc.debugging;

import linalg.misc.types;
import linalg.storage.regular2d;
import linalg.operations.basic;

/*
 * Bindings
 */
private version(linalg_backend_lapack)
{
    import linalg.backends.lapack;

    alias linalg.backends.lapack.inverseMatrix inverseMatrix;
}

/* Matrix inversion */
void matrixInverse(Tsource, Tdest)(auto ref Tsource source,
                                   auto ref Tdest dest) pure
    if(isStorageRegular2D!Tsource && isStorageRegular2D!Tdest)
    in
    {
        assert(source.nrows == source.ncols);
        assert(dest.dim == source.dim);
    }
body
{
    debug(linalg_operations) dfoOp2("matrix inversion",
                                    source.container,
                                    dest.container);
    inverseMatrix(source.container, source.nrows, dest.container);
}
