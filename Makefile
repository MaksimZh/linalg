DMD=~/programming/dlang/dmd/src/dmd
#DMD=dmd

test: test.d compactarray.d stride.d mdarray.d aux.d iteration.d containers.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/compactarray.bundle --all
