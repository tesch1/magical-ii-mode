EMACS ?= emacs

.PHONY: all compile test checkdoc clean

all: compile test

compile:
	$(EMACS) -Q --batch -L . -f batch-byte-compile magicalii-mode.el

test:
	$(EMACS) -Q --batch -L . -l test/magicalii-mode-tests.el -f ert-run-tests-batch-and-exit

checkdoc:
	$(EMACS) -Q --batch --eval "(checkdoc-file \"magicalii-mode.el\")"

clean:
	rm -f *.elc test/*.elc
