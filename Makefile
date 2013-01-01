test: test.d arrax.d codeindex.d
	dmd -debug -unittest $^

backup:
	git bundle create ~/Dropbox/arrax.bundle --all
