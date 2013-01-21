test: test.d arrax.d stride.d aux.d
	dmd -debug -unittest $^

backup:
	git bundle create ~/Dropbox/arrax.bundle --all
