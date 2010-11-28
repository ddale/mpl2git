SVN=$(CURDIR)/../mpl-svn

help:
	@echo "Targets:"
	@echo ""
	@echo "  make clean"
	@echo "  make export SVN=...  -- svn-all-fast-export"
	@echo "  make postprocess     -- postprocess"
	@echo "  make final-cleanup   -- final cleanup"
	@echo "  make gc              -- git-gc"
	@echo ""
	@echo "  make graft           -- (re-)do merge grafting"
	@echo "  make branchstat      -- show branch status"
	@echo ""

all: clean export postprocess final-cleanup gc

clean:
	rm -rf matplotlib matplotlib.save vendor log-* revisions-matplotlib \
	    revisions-vendor verify-matplotlib.git

svn2git:
	git clone git://gitorious.org/svn2git/svn2git.git svn2git

svn2git/svn-all-fast-export: svn2git
	cd svn2git && git checkout -f e1bebdeb4 && git clean -f -x
	cd svn2git && qmake
	make -C svn2git

export: svn2git/svn-all-fast-export
	./svn2git/svn-all-fast-export \
	  --identity-map authors.map \
	  --rules matplotlib.rules \
	  --add-metadata \
	  --commit-interval 500 \
	  $(SVN) \
	2>&1 | tee log-matplotlib-export
	rm -rf matplotlib.save
	cp -a matplotlib matplotlib.save

verify-matplotlib.git:
	./tree-checksum.py --all-git matplotlib.save | tee $@

verify-matplotlib.svn:
	./tree-checksum.py --all-svn $(SVN) | tee $@

verify: verify-matplotlib.git verify-matplotlib.svn
	./tree-checksum.py --compare verify-matplotlib.svn verify-matplotlib.git

graft:
	./postprocess.sh matplotlib matplotlib.grafts graft-only
	./branchstat.sh matplotlib matplotlib.branchskip

branchstat:
	./branchstat.sh matplotlib matplotlib.branchskip

postprocess:
	./postprocess.sh matplotlib matplotlib.grafts

final-cleanup:
	install -d matplotlib/refs/svn/backups
	find matplotlib/refs/backups -type f \
	| while read F; do \
		NEWF=`echo "$$F"|sed -e 's@.*/r\([0-9]\+\)/.*/\([^/]\+\)$$@\2_\1@'`; \
		mv "$$F" matplotlib/refs/svn/backups/"$$NEWF"; \
	done
	rm -rf matplotlib/refs/original
	rm -rf matplotlib/refs/backups

gc:
	for repo in matplotlib  ; do \
	    (cd $$repo && \
	     git repack -f -a -d --depth=500 --window=250 && \
	     git gc --prune=0); \
	done

.PHONY: help all clean export graft final-cleanup postprocess gc verify
