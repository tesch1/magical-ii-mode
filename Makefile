EMACS ?= emacs

.PHONY: all compile test checkdoc corpus clean

CORPUS ?= ../OpenVnmrJ/src

all: compile test

compile:
	$(EMACS) -Q --batch -L . -f batch-byte-compile magicalii-mode.el

test:
	$(EMACS) -Q --batch -L . -l test/magicalii-mode-tests.el -f ert-run-tests-batch-and-exit

checkdoc:
	$(EMACS) -Q --batch --eval "(checkdoc-file \"magicalii-mode.el\")"

corpus:
	$(EMACS) -Q --batch -L . -l test/corpus.el $(CORPUS)

clean:
	rm -f *.elc test/*.elc
