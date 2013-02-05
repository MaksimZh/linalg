DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd

test: test.d stride.d mdarray.d iteration.d aux.d storage.d array.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/compactarray.bundle --all
