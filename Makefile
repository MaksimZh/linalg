DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd

test: test.d stride.d mdarray.d aux.d iteration.d base.d array.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/compactarray.bundle --all
