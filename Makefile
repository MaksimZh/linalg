test: test.d arrax.d
	dmd -debug -debug=slices -unittest $^

backup:
	git bundle create ~/Dropbox/arrax.bundle --all
