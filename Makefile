DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd

test: test.d storage.d stride.d mdarray.d iteration.d aux.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/compactarray.bundle --all
