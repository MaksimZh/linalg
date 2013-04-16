// Written in the D programming language.

/**
 * Wrappers for LAPACK functions used in linalg.storage.operations
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.backends.lapack;

/*
 * If corresponding backend is not specified then the following code
 * will not be compiled and there will be no linker errors.
 */
version(linalg_backend_lapack):

import std.complex;
import std.conv;
import std.typecons;

private extern(C) void zheev_(in char* JOBZ,
                              in char* UPLO,
                              in int* N,
                              Complex!double* A,
                              in int* LDA,
                              double* W,
                              Complex!double* WORK,
                              in int* LWORK,
                              double* RWORK,
                              int* INFO) pure;

auto symmEigenval(ElementType)(ElementType[] mx, size_t dim) pure
    if(is(ElementType == Complex!double))
{
    int N = to!int(dim);
    int LDA = to!int(dim);
    auto tmpval = new double[dim];
    int LWORK = 2*N;
    auto WORK = new Complex!double[LWORK];
    auto RWORK = new double[3*N - 2];
    int info;
    zheev_("N", "U",
           &N, mx.ptr, &LDA,
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
                               int* INFO) pure;

auto symmEigenval(ElementType)(ElementType[] mx, size_t dim,
                               size_t ilo, size_t iup) pure
    if(is(ElementType == Complex!double))
{
    size_t valNum = iup - ilo + 1;
    int N = to!int(dim);
    int LDA = to!int(dim);
    int IL = to!int(ilo + 1);
    int IU = to!int(iup + 1);
    int M;
    auto tmpval = new double[dim];
    int LDZ = 1;
    int LWORK = 2*N;
    auto WORK = new Complex!double[LWORK];
    auto RWORK = new double[7*N];
    auto IWORK = new int[5*N];
    auto IFAIL = new int[N];
    int info;
    zheevx_("N", "I", "U",
            &N, mx.ptr, &LDA,
            null, null,
            &IL, &IU,
            &abstol,
            &M,
            tmpval.ptr, null, &LDZ,
            WORK.ptr, &LWORK, RWORK.ptr, IWORK.ptr,
            IFAIL.ptr, &info);
    return tmpval[0..valNum];
}

auto symmEigenAll(ElementType)(ElementType[] mx, size_t dim,
                               size_t ilo, size_t iup) pure
    if(is(ElementType == Complex!double))
{
    size_t valNum = iup - ilo + 1;
    int N = to!int(dim);
    int LDA = to!int(dim);
    int IL = to!int(ilo + 1);
    int IU = to!int(iup + 1);
    int M;
    auto tmpval = new double[dim];
    auto vec = new Complex!double[N * valNum];
    int LDZ = N;
    int LWORK = 2*N;
    auto WORK = new Complex!double[LWORK];
    auto RWORK = new double[7*N];
    auto IWORK = new int[5*N];
    auto IFAIL = new int[N];
    int info;
    zheevx_("V", "I", "U",
            &N, mx.ptr, &LDA,
            null, null,
            &IL, &IU,
            &abstol,
            &M,
            tmpval.ptr, vec.ptr, &LDZ,
            WORK.ptr, &LWORK, RWORK.ptr, IWORK.ptr,
            IFAIL.ptr, &info);
    return tuple(tmpval[0..valNum], vec);
}
