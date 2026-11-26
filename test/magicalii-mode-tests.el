;;; magicalii-mode-tests.el --- Tests for magicalii-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with: make test

;;; Code:

(require 'ert)
(require 'magicalii-mode)
(require 'subr-x)

(defconst magicalii-test-sample
  "\"macro demo\"
\"demo - sample macro for the tests\"

// line comment
/* block
   comment */
if ($# < 1) then $1 = 'proton' endif
getlimit('dpwr'):$max,$min,$step
IF ($1 = 'proton') THEN
    $i = 1
    repeat
        wft f full
        $i = $i + 1
    until ($i > 3)
ELSEIF ($1 = 'carbon') THEN
    while ($i < 10) do
        write('line3', 'i=%d', $i)
        if (console = 'inova') then
            gain = 20
        else
            gain = 40
        endif
        $i = $i + 1
    endwhile
else
    mymacro(1, 2,
            3)
    pw[2] = 7.5 abort
endif
tn='C13' dn='H1' seqfil=seqfil
$s = `it's a string`
return
"
  "A correctly indented macro.")

(defmacro magicalii-test-with-sample (&rest body)
  "Run BODY in a `magicalii-mode' buffer with the sample macro."
  (declare (indent 0))
  `(with-temp-buffer
     (insert magicalii-test-sample)
     (magicalii-mode)
     (font-lock-ensure)
     (goto-char (point-min))
     ,@body))

(defun magicalii-test-face (text &optional nth)
  "Return the face at the NTH occurrence (default 1) of TEXT."
  (goto-char (point-min))
  (let ((case-fold-search nil))
    (search-forward text nil nil (or nth 1)))
  (get-text-property (match-beginning 0) 'face))

(defun magicalii-test-face-p (face text &optional nth)
  "Return non-nil if the NTH occurrence of TEXT has FACE."
  (let ((f (magicalii-test-face text nth)))
    (if (listp f) (memq face f) (eq face f))))

(ert-deftest magicalii-test-indent-region ()
  (magicalii-test-with-sample
    (let ((indent-tabs-mode nil))
      (while (not (eobp))
        (unless (nth 8 (syntax-ppss (line-beginning-position)))
          (delete-horizontal-space)
          (back-to-indentation)
          (delete-horizontal-space))
        (forward-line 1))
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) magicalii-test-sample)))))

(ert-deftest magicalii-test-electric-dedent ()
  (with-temp-buffer
    (magicalii-mode)
    (electric-indent-local-mode 1)
    (insert "if $x then\n")
    (indent-according-to-mode)
    (should (= (current-column) magicalii-indent-offset))
    (dolist (c (string-to-list "endif"))
      (let ((last-command-event c))
        (self-insert-command 1)))
    (should (= (current-indentation) 0))))

(ert-deftest magicalii-test-comments ()
  (magicalii-test-with-sample
    (dolist (text '("macro demo" "line comment" "block" "   comment"))
      (goto-char (point-min))
      (search-forward text)
      (should (nth 4 (syntax-ppss))))
    (should (magicalii-test-face-p 'font-lock-comment-face "demo - sample"))
    (should (magicalii-test-face-p 'font-lock-comment-face "line comment"))
    (should (magicalii-test-face-p 'font-lock-comment-face "block"))))

(ert-deftest magicalii-test-unclosed-quote-comment ()
  (with-temp-buffer
    (insert "\"  Modification History\nif $x then\nwft \"note\" f\nendif\n")
    (magicalii-mode)
    (font-lock-ensure)
    (should (magicalii-test-face-p 'font-lock-comment-face "History"))
    (should (magicalii-test-face-p 'font-lock-keyword-face "if $x"))
    (should (magicalii-test-face-p 'font-lock-builtin-face "wft"))
    (should (magicalii-test-face-p 'font-lock-comment-face "note"))
    (should (magicalii-test-face-p 'font-lock-builtin-face "f\n"))
    (should (magicalii-test-face-p 'font-lock-keyword-face "endif"))))

(ert-deftest magicalii-test-strings ()
  (magicalii-test-with-sample
    (should (magicalii-test-face-p 'font-lock-string-face "proton"))
    (should (magicalii-test-face-p 'font-lock-string-face "s a string"))
    (goto-char (point-min))
    (search-forward "return")
    (should-not (nth 8 (syntax-ppss)))))

(ert-deftest magicalii-test-keywords ()
  (magicalii-test-with-sample
    (dolist (kw '("if (" "IF" "THEN" "ELSEIF" "repeat" "until" "while"
                  " do" "endwhile" "endif" "abort" "return"))
      (should (magicalii-test-face-p
               'font-lock-keyword-face (string-trim kw))))))

(ert-deftest magicalii-test-variables ()
  (magicalii-test-with-sample
    (should (magicalii-test-face-p 'magicalii-argument "$#"))
    (should (magicalii-test-face-p 'magicalii-argument "$1"))
    (should (magicalii-test-face-p 'magicalii-local-variable "$max"))
    (should (magicalii-test-face-p 'magicalii-local-variable "$i"))
    (should (magicalii-test-face-p 'font-lock-variable-name-face "gain"))
    (should (magicalii-test-face-p 'font-lock-variable-name-face "pw["))
    (should (magicalii-test-face-p 'font-lock-variable-name-face "dn="))
    (should-not (magicalii-test-face "console"))
    (should-not (magicalii-test-face "seqfil" 2))))

(ert-deftest magicalii-test-commands ()
  (magicalii-test-with-sample
    (should (magicalii-test-face-p 'font-lock-builtin-face "wft"))
    (should (magicalii-test-face-p 'font-lock-builtin-face "f full"))
    (should (magicalii-test-face-p 'font-lock-builtin-face "write"))
    (should (magicalii-test-face-p magicalii--function-call-face "mymacro"))
    (should (magicalii-test-face-p 'font-lock-builtin-face "getlimit"))))

(ert-deftest magicalii-test-auto-mode ()
  (should (eq (assoc-default "/home/u/vnmrsys/maclib/foo"
                             auto-mode-alist #'string-match)
              'magicalii-mode)))

(provide 'magicalii-mode-tests)
;;; magicalii-mode-tests.el ends here
