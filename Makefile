//DMD=~/programming/dlang/dmd/src/dmd
DMD=dmd

test: test.d arrax.d stride.d mdarray.d aux.d iteration.d
	$(DMD) -debug -unittest $^

backup:
	git bundle create ~/Dropbox/arrax.bundle --all
