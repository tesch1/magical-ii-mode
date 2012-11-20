; Copyright (c) 2012, Regents of the University of Minnesota
; All rights reserved.
; 
; Redistribution and use in source and binary forms, with or without 
; modification, are permitted provided that the following conditions are met:
;
;  - Redistributions of source code must retain the above copyright notice, 
;    this list of conditions and the following disclaimer.
;  - Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the 
;    documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
; POSSIBILITY OF SUCH DAMAGE.
;
; author: michael tesch <tesch@cmrr.umn.edu>
; with a lot of help from: http://ergoemacs.org/emacs/elisp_basics.html
;
; to install this mode into your emacs installation, and have it automatically
; pick up all files wiht a */maclib/* in their path, add the following to
; your initialization file:
;
; (require magicalii-mode)
; -or-
; (autoload 'magicalii-mode "...path/to/magicalii-mode.el" t)
;
; then:
; (add-to-list 'auto-mode-alist 
;   '(".*/maclib/*." . magicalii-mode))
;

;; define several class of keywords
(defvar magical-keywords
  '("abort" "abortoff" "aborton" "and" "break" "do" "else" "elseif" "endif" 
    "endwhile" "if" "mod" "not" "or" "repeat" "return" "size" "sqrt" "trunc"
    "typeof" "then" "until" "while")
  "Magical keywords.")

;; builtin functions (for which no maclib/ file exists)
(defvar magical-builtin
  '("exist" "write" "substr" "destroy" "vnmrjcmd" "teststr" "readfile" "create"
    "format" "string2array" "teststr" "purge" "string" "real" "setlimit" "input")
  "Magical builtin functions.")

; constants should be strings and reals -- todo: check for real & real bounds
(defvar magical-constant
  '("macro")
  "Magical constant variables.")

(defvar magical-functions
  '("blahhh")
  "Magical functions.")

;; create the regex string for each class of keywords
(defvar magical-keywords-regexp (regexp-opt magical-keywords 'words))
(defvar magical-constant-regexp (regexp-opt magical-constant 'words))
(defvar magical-builtin-regexp (regexp-opt magical-builtin 'words))
(defvar magical-functions-regexp (regexp-opt magical-functions 'words))

;; clear memory
(setq magical-keywords nil)
(setq magical-constant nil)
(setq magical-builtin nil)
(setq magical-functions nil)

;; create the list for font-lock.
;; each class of keyword is given a particular face
(setq magical-font-lock-keywords
  `(
    (,magical-builtin-regexp . font-lock-builtin-face)
    (,magical-constant-regexp . font-lock-constant-face)
    (,magical-functions-regexp . font-lock-function-name-face)
    (,magical-keywords-regexp . font-lock-keyword-face)
    ;; note: order above matters. "magical-keywords-regexp" goes last because
    ;; otherwise the keyword "state" in the function "state_entry"
    ;; would be highlighted.
))

;; syntax table
(defvar magical-syntax-table nil "Syntax table for `magicalii-mode'.")
(setq magical-syntax-table
      (let ((synTable (make-syntax-table)))
        ;; C++ style comment “// ” & “/* ... */” 
        ;(modify-syntax-entry ?\/ ". 124" synTable)
        ;(modify-syntax-entry ?* ". 23b" synTable)
        ;(modify-syntax-entry ?\n ">" synTable)
        (if (string-match "XEmacs" emacs-version)
            (progn(modify-syntax-entry ?\/ ". 1456" synTable)
                  (modify-syntax-entry ?* ". 23" synTable)
                  (modify-syntax-entry ?\n "> b" synTable))
          (progn(modify-syntax-entry ?\/ ". 124" synTable)
                (modify-syntax-entry ?* ". 23b" synTable)
                (modify-syntax-entry ?\n ">" synTable)
                (message "HELLO")))

        ;; double-quotes are for comments
        ;(modify-syntax-entry ?\" "<" synTable)
        ;; single-quotes are for strings
        (modify-syntax-entry ?\' "\"" synTable)
        ;; so are back-single-quotes are for strings
        (modify-syntax-entry ?\` "\"" synTable)
;        (modify-syntax-entry ?$ " |_" synTable)
        synTable))

;; indent
(defun magical-indent-line ()
  "Indent a line in `magicalii-mode'."
  (interactive)
  (beginning-of-line)
  (if (bobp)  ; Check for beginning of buffer
      (indent-line-to 0)
    )
)

;; define the mode
(define-derived-mode magicalii-mode fundamental-mode
  "MagicalII mode"
  "Major mode for editing Agilent (ne Varian) MagicalII scripts …"
  :syntax-table magical-syntax-table

  ;; code for syntax highlighting
  (setq font-lock-defaults '((magical-font-lock-keywords)))

  ;; setup indent
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'magical-indent-line)

  ;; clear memory
  (setq magical-keywords-regexp nil)
  (setq magical-builtin-regexp nil)
  (setq magical-functions-regexp nil)
)

(provide 'magicalii-mode)
