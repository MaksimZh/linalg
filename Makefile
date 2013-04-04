DMD=~/programming/dlang/dmd/src/dmd -I../dlang/phobos -I../dlang/druntime/import -L"-L../dlang"
LIBS=../../Applications/lapack-3.4.1/liblapack.a ../../Applications/lapack-3.4.1/librefblas.a -L-lgfortran
SOURCE=$(shell find ./linalg/ -name "*.d")
DEBUGFLAGS=operations slice storage container cow copy matrix

test: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug $(addprefix -debug=, $(DEBUGFLAGS)) -unittest -version=linalg_backend_lapack

unittest: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug $(addprefix -debug=, $(DEBUGFLAGS)) -debug=unittests -unittest -version=linalg_backend_lapack

backup:
	git bundle create ~/Dropbox/linalg.bundle --all
