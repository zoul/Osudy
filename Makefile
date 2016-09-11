all: feed
feed:
	./podcastify.swift > feed.xml
	git stash -u
	git checkout gh-pages
	rm feed.xml
	git stash apply
	git commit -am "Feed update"
	git checkout master
