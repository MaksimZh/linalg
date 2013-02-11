DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd
LIBS=../../Applications/lapack-3.4.1/liblapack.a ../../Applications/lapack-3.4.1/librefblas.a -L-lgfortran

test: test.d stride.d mdarray.d iterators.d aux.d operations.d storage.d array.d matrix.d
	$(DMD) $^ $(LIBS) -debug -unittest -version=backend_lapack

backup:
	git bundle create ~/Dropbox/linalg.bundle --all
