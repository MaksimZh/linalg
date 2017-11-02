// Written in the D programming language.

/**
 * Wrappers for LAPACK functions used in linalg.storage.operations
 *
 * Authors:    Maksim Sergeevich Zholudev
 * Copyright:  Copyright (c) 2013, Maksim Zholudev
 * License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module linalg.backends.mkl;

/*
 * If corresponding backend is not specified then the following code
 * will not be compiled and there will be no linker errors.
 */
version(linalg_backend_mkl):

import std.complex;
import std.conv;
import std.typecons;

debug import std.stdio;


auto symmEigenval(ElementType)(ElementType[] mx, size_t dim) pure
    if(is(ElementType == Complex!double))
{
    auto values = new double[dim];
    lapack_int n = cast(lapack_int) dim;
    lapack_int info = LAPACKE_zheev(
        LAPACK_ROW_MAJOR, 'N', 'U', n, mx.ptr, n, values.ptr);
    return values;
}

auto symmEigenval(ElementType)(ElementType[] mx, size_t dim,
                               size_t ilo, size_t iup) pure
    if(is(ElementType == Complex!double))
{
    auto values = new double[dim];
    size_t valNum = iup - ilo + 1;
    lapack_int n = cast(lapack_int) dim;
    lapack_int il = cast(lapack_int) ilo + 1;
    lapack_int iu = cast(lapack_int) iup + 1;
    lapack_int m;
    auto ifail = new lapack_int[dim];
    lapack_int info = LAPACKE_zheevx(
        LAPACK_ROW_MAJOR, 'N', 'I', 'U',
        n, mx.ptr, n,
        0, 0, il, iu,
        abstol,
        &m, values.ptr,
        null, 1, ifail.ptr);
    return values[0..valNum];
}


private:

enum double abstol = 1e-12;
alias lapack_int = long;
alias lapack_complex_double = Complex!double;
alias mkl_int = long;

enum int LAPACK_ROW_MAJOR = 101;
enum int LAPACK_COL_MAJOR = 102;

extern(C)
pure lapack_int LAPACKE_zheev(
    int matrix_layout, char jobz, char uplo, lapack_int n,
    lapack_complex_double* a, lapack_int lda, double* w);

extern(C)
pure lapack_int LAPACKE_zheevx(
    int matrix_layout, char jobz, char range, char uplo,
    lapack_int n, lapack_complex_double* a, lapack_int lda,
    double vl, double vu, lapack_int il, lapack_int iu,
    double abstol,
    lapack_int* m, double* w,
    lapack_complex_double* z, lapack_int ldz, lapack_int* ifail);

extern(C)
pure lapack_int LAPACKE_zheevr(
    int matrix_layout, char jobz, char range, char uplo,
    lapack_int n, lapack_complex_double* a, lapack_int lda,
    double vl, double vu, lapack_int il, lapack_int iu,
    double abstol,
    lapack_int* m, double* w,
    lapack_complex_double* z, lapack_int ldz, lapack_int* isuppz);
