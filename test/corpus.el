;;; corpus.el --- Check magicalii-mode on a directory tree of macros -*- lexical-binding: t; -*-

;;; Commentary:

;; Usage: make corpus CORPUS="DIR..."
;;
;; Finds every file below each DIR in a directory named maclib*, then
;; runs font lock and `indent-region' on it in a temporary buffer.
;; The files are not changed.  Each file with a problem is printed
;; with the problem, followed by a summary.  The exit status is 1 if
;; any file has an error.

;;; Code:

(require 'magicalii-mode)
(require 'cl-lib)

(defvar magicalii-corpus-slow 1.0
  "Seconds after which a file counts as slow.")

(defun magicalii-corpus--files (dir)
  "Return the macro files below DIR."
  (cl-remove-if-not
   (lambda (f)
     (and (file-regular-p f)
          (string-match-p "/maclib[^/]*/[^/]+\\'" f)))
   (directory-files-recursively dir "" nil)))

(defun magicalii-corpus--check-buffer ()
  "Check the current buffer and return a list of problem strings."
  (let ((problems '())
        (t0 (float-time))
        (inhibit-message t)
        (message-log-max nil))
    (font-lock-ensure)
    (let ((end (save-excursion (syntax-ppss (point-max)))))
      (when (nth 3 end) (push "unclosed string" problems))
      (when (nth 4 end) (push "unclosed comment" problems))
      (unless (zerop (nth 0 end))
        (push (format "paren depth %d at end" (nth 0 end)) problems)))
    (let ((depth (magicalii--block-change (point-min) (point-max))))
      (unless (zerop depth)
        (push (format "block depth %+d at end" depth) problems)))
    (indent-region (point-min) (point-max))
    (let ((once (buffer-string)))
      (indent-region (point-min) (point-max))
      (unless (string= once (buffer-string))
        (push "indentation not stable" problems)))
    (let ((dt (- (float-time) t0)))
      (when (> dt magicalii-corpus-slow)
        (push (format "slow: %.1fs" dt) problems)))
    (nreverse problems)))

(defun magicalii-corpus-run (dirs)
  "Check all macro files below DIRS and print a report."
  (let ((total 0) (bad 0) (errors 0) (counts (make-hash-table :test 'equal)))
    (dolist (dir dirs)
      (dolist (f (magicalii-corpus--files (expand-file-name dir)))
        (with-temp-buffer
          (insert-file-contents f)
          (unless (save-excursion (search-forward "\0" nil t))
            (setq total (1+ total))
            (let ((indent-tabs-mode nil))
              (magicalii-mode)
              (let ((problems
                     (condition-case err
                         (magicalii-corpus--check-buffer)
                       (error (setq errors (1+ errors))
                              (list (format "ERROR %S" err))))))
                (when problems
                  (setq bad (1+ bad))
                  (dolist (p problems)
                    (let ((key (replace-regexp-in-string "[-+]?[0-9.]+s?" "N" p)))
                      (puthash key (1+ (gethash key counts 0)) counts)))
                  (princ (format "%s: %s\n" (file-relative-name f dir)
                                 (mapconcat #'identity problems "; "))))))))))
    (princ (format "\n%d files, %d with problems, %d errors\n" total bad errors))
    (maphash (lambda (k v) (princ (format "  %5d  %s\n" v k))) counts)
    (kill-emacs (if (zerop errors) 0 1))))

(magicalii-corpus-run command-line-args-left)
(setq command-line-args-left nil)

(provide 'corpus)
;;; corpus.el ends here
