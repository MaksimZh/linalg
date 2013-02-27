DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd
LIBS=../../Applications/lapack-3.4.1/liblapack.a ../../Applications/lapack-3.4.1/librefblas.a -L-lgfortran
SOURCE=$(shell find ./ -name "*.d" ! -name "test.d")

test: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug -unittest -version=backend_lapack

backup:
	git bundle create ~/Dropbox/linalg.bundle --all
