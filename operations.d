// Written in the D programming language.

/** Perform arithmetic and other operations on storages.

    Authors:    Maksim S. Zholudev
    Copyright:  Copyright (c) 2013, Maksim S. Zholudev.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module linalg.operations;

import linalg.storage;

debug import std.stdio;

bool compare(Tsource, Tdest)(in Tsource source, in Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
{
    auto isource = source.byElement!false;
    auto idest = dest.byElement!false;
    foreach(ref d; idest)
    {
        if(d != isource.front)
            return false;
        isource.popFront();
    }
    return true;
}

void copy(Tsource, Tdest)(in Tsource source, ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
        in
        {
            assert(dest.isCompatibleDimensions(source.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source);
    auto isource = source.byElement!false;
    auto idest = dest.byElement!true;
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }
}

void applyUnary(string op, Tsource, Tdest)(in Tsource source, ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
        in
        {
            assert(dest.isCompatibleDimensions(source.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source);
    auto isource = source.byElement!false;
    auto idest = dest.byElement!true;
    foreach(ref d; idest)
    {
        d = mixin(op ~ "isource.front");
        isource.popFront();
    }
}

void applyBinary(string op, Tsource1, Tsource2, Tdest)(in Tsource1 source1,
                                                       in Tsource2 source2,
                                                       ref Tdest dest)
    if(isStorage!Tsource1 && isStorage!Tsource2 && isStorage!Tdest)
        in
        {
            assert(source1.dimensions == source2.dimensions);
            assert(dest.isCompatibleDimensions(source1.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source1);
    auto isource1 = source1.byElement!false;
    auto isource2 = source2.byElement!false;
    auto idest = dest.byElement!true;
    foreach(ref d; idest)
    {
        d = mixin("isource1.front" ~ op ~ "isource2.front");
        isource1.popFront();
        isource2.popFront();
    }
}

void matrixTranspose(Tsource, Tdest)(in Tsource source,
                                     ref Tdest dest)
    if(isStorage!Tsource && isStorage!Tdest)
        in
        {
            assert(dest.isCompatibleDimensions(source.dimensions));
        }
body
{
    static if(dest.isResizeable)
        dest.fit(source);
    auto isource = source.byElement!false;
    auto idest = dest.byElementTr!true;
    foreach(ref d; idest)
    {
        d = isource.front;
        isource.popFront();
    }

}


void matrixMult(Tsource1, Tsource2, Tdest)(ref Tsource1 source1,
                                           ref Tsource2 source2,
                                           ref Tdest dest)
    if(isStorage!Tsource1 && isStorage!Tsource2 && isStorage!Tdest)
        in
        {
            assert(source1.dimensions[1] == source2.dimensions[0]);
            assert(dest.isCompatibleDimensions([source1.dimensions[0],
                                                source2.dimensions[1]]));
        }
body
{
    /* FIXME: probably this is the ugliest implementation
       of matrix multiplication ever */
    static if(dest.isResizeable)
        dest.setAllDimensions([source1.dimensions[0], source2.dimensions[1]]);
    auto idest = dest.byElement!true;
    foreach(row; source1.byRow)
        foreach(col; source2.byCol)
        {
            auto irow = row.byElement!false;
            auto icol = col.byElement!false;
            /* Can not just write front = 0 in generic code. */
            idest.front = irow.front * icol.front;
            irow.popFront();
            icol.popFront();
            while(!(irow.empty))
            {
                idest.front += irow.front * icol.front;
                irow.popFront();
                icol.popFront();
            }
            idest.popFront();
        }
}

version(backend_lapack)
{
    import std.complex;
    import std.conv;
    import linalg.matrix; //FIXME

    private extern(C) void zheev_(in char* JOBZ,
                                  in char* UPLO,
                                  in int* N,
                                  Complex!double* A,
                                  in int* LDA,
                                  double* W,
                                  Complex!double* WORK,
                                  in int* LWORK,
                                  double* RWORK,
                                  int* INFO);

    double[] matrixSymmEigenval(Tsource)(in Tsource source)
        if(isStorage!Tsource && is(Tsource.ElementType == Complex!double))
    {
        /*FIXME: This is a temporary implementation */
        Matrix!(Complex!double, dynamicSize, dynamicSize, StorageOrder.colMajor)
            mx;
        copy(source, mx.storage);
        int N = to!int(mx.ncols);
        int LDA = to!int(mx.nrows);
        auto tmpval = new double[mx.ncols];
        int LWORK = 2*N;
        auto WORK = new Complex!double[LWORK];
        auto RWORK = new double[3*N - 2];
        int info;
        zheev_("N", "U",
               &N, mx.storage._data.ptr, &LDA,
               tmpval.ptr,
               WORK.ptr, &LWORK, RWORK.ptr,
               &info);
        return tmpval;
    }

    private immutable double abstol = 1e-12; //TODO: move elsewhere

    private extern(C) void zheevx_(in char* JOBZ,
                                   in char* RANGE,
                                   in char* UPLO,
                                   in int* N,
                                   Complex!double* A,
                                   in int* LDA,
                                   in double* VL,
                                   in double* VU,
                                   in int* IL,
                                   in int* IU,
                                   in double* ABSTOL,
                                   int* M,
                                   double* W,
                                   Complex!double* Z,
                                   in int* LDZ,
                                   Complex!double* WORK,
                                   in int* LWORK,
                                   double* RWORK,
                                   int* IWORK,
                                   int* IFAIL,
                                   int* INFO);

    double[] matrixSymmEigenval(Tsource)(in Tsource source, uint ilo, uint iup)
        if(isStorage!Tsource && is(Tsource.ElementType == Complex!double))
    {
        /*FIXME: This is a temporary implementation */
        Matrix!(Complex!double, dynamicSize, dynamicSize, StorageOrder.colMajor)
            mx;
        copy(source, mx.storage);
        int N = to!int(mx.ncols);
        int LDA = to!int(mx.nrows);
        int IL = to!int(ilo + 1);
        int IU = to!int(iup + 1);
        int M;
        auto tmpval = new double[mx.ncols];
        int LDZ = 1;
        int LWORK = 2*N;
        auto WORK = new Complex!double[LWORK];
        auto RWORK = new double[7*N];
        auto IWORK = new int[5*N];
        auto IFAIL = new int[N];
        int info;
        zheevx_("N", "I", "U",
                &N, mx.storage._data.ptr, &LDA,
                null, null,
                &IL, &IU,
                &abstol,
                &M,
                tmpval.ptr, null, &LDZ,
                WORK.ptr, &LWORK, RWORK.ptr, IWORK.ptr,
                IFAIL.ptr, &info);
        return tmpval[0..(iup - ilo + 1)];
    }
}
