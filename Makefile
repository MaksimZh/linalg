DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd

test: test.d stride.d mdarray.d iterators.d aux.d operations.d storage.d array.d matrix.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/linalg.bundle --all
