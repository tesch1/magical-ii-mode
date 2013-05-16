magical-ii-mode
===============

emacs mode for editing magical-ii scripts for varian / agilent vnmrj

install
=======
to install this mode into your emacsen, and have it automatically
pick up all files wiht a */maclib/* in their path, add the following to
your favorite initialization file:

    (autoload 'magicalii-mode "...path/to/magicalii-mode.el" t)
    (add-to-list 'auto-mode-alist 
      '(".*/maclib/*." . magicalii-mode))

and copy the magicalii-mode.el somewhere convenient (~/.xemacs/)
