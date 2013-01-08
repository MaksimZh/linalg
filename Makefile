test: test.d arrax.d
	dmd -debug -unittest $^

backup:
	git bundle create ~/Dropbox/arrax.bundle --all
