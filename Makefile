# Use DMD from Git
DMD=~/programming/dlang/dmd/src/dmd -I../dlang/phobos -I../dlang/druntime/import -L"-L../dlang"
# Paths to LAPACK and BLAS
# LIBS=../../Applications/lapack-3.4.1/liblapack.a ../../Applications/lapack-3.4.1/librefblas.a -L-lgfortran
LIBS=-L-llapack -L-lblas -L-lgfortran
SOURCE=$(shell find ./linalg/ -name "*.d")
DEBUGFLAGS=operations slice storage matrix range

# Version without debug output
test: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug -unittest -version=linalg_backend_lapack

# Version without debug output from unittests
testv: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug $(addprefix -debug=, $(DEBUGFLAGS)) -unittest -version=linalg_backend_lapack

# Version with debug output from unittests
unittest: test.d $(SOURCE)
	$(DMD) $^ $(LIBS) -debug $(addprefix -debug=, $(DEBUGFLAGS)) -debug=unittests -unittest -version=linalg_backend_lapack

backup:
	git bundle create ~/Dropbox/linalg.bundle --all
