;;; magicalii-mode.el --- Major mode for VnmrJ MAGICAL II macros -*- lexical-binding: t; -*-

;; Copyright (c) 2026 michael tesch
;; All rights reserved.

;; Author: michael tesch <tesch1@gmail.com>
;; Maintainer: michael tesch <tesch1@gmail.com>
;; URL: https://github.com/tesch1/magical-ii-mode
;; Version: 1.0.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: languages
;; SPDX-License-Identifier: BSD-3-Clause

;; This file is not part of GNU Emacs.

;;; License:

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:
;;
;;  - Redistributions of source code must retain the above copyright notice,
;;    this list of conditions and the following disclaimer.
;;  - Redistributions in binary form must reproduce the above copyright notice,
;;    this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;; POSSIBILITY OF SUCH DAMAGE.

;;; Commentary:

;; A major mode for editing MAGICAL II macros, the scripting language
;; of Agilent (formerly Varian) VnmrJ and OpenVnmrJ NMR software.
;;
;; Features:
;;
;;  - Syntax highlighting of keywords, built-in commands, macro calls,
;;    parameter assignments, local variables ($x) and macro arguments
;;    ($0, $1, ..., $#).
;;  - All three comment forms: "...", // ... and /* ... */.
;;  - Both string forms: '...' and `...`, with backslash escapes.
;;  - Indentation of if/elseif/else/endif, while/do/endwhile and
;;    repeat/until blocks, with electric re-indentation of closers.
;;  - `magicalii-describe-command' (C-c C-d) opens the VnmrJ manual
;;    page for a command, and `magicalii-find-macro' (C-c C-f) opens
;;    the macro file from the maclib search path.
;;
;; Files in any directory named "maclib" open in this mode.  For other
;; files, use M-x magicalii-mode or a file-local variable.
;;
;; The syntax follows the MAGICAL lexer and grammar of OpenVnmrJ
;; (src/vnmr/magic.lex.l and magic.gram.y); the list of built-in
;; commands comes from its command table (src/vnmr/table.c).

;;; Code:

(defgroup magicalii nil
  "Editing MAGICAL II macros for Agilent/Varian VnmrJ."
  :group 'languages
  :prefix "magicalii-"
  :link '(url-link "https://github.com/tesch1/magical-ii-mode"))

(defcustom magicalii-indent-offset 4
  "Number of columns for each nesting level of MAGICAL II blocks."
  :type 'integer
  :safe #'integerp)

(defcustom magicalii-comment-style 'quote
  "Comment form that the comment commands insert.
The value `quote' gives \"...\" comments, `slash' gives // comments."
  :type '(choice (const :tag "\"...\"" quote)
                 (const :tag "// ..." slash))
  :safe #'symbolp)

(defcustom magicalii-manual-directory "/vnmr/manual"
  "Directory that holds the VnmrJ command manual pages."
  :type 'directory)

(defcustom magicalii-macro-path '("~/vnmrsys/maclib" "/vnmr/maclib")
  "Directories to search for macro files, in order."
  :type '(repeat directory))

(defface magicalii-local-variable
  '((t :inherit font-lock-variable-name-face))
  "Face for local variables such as $x.")

(defface magicalii-argument
  '((t :inherit font-lock-constant-face))
  "Face for the macro name $0, the arguments $1, $2, ... and the count $#.")

(defconst magicalii--function-call-face
  (if (facep 'font-lock-function-call-face)
      'font-lock-function-call-face
    'font-lock-function-name-face)
  "Face for calls of macros and commands that are not built in.")

;;;; Vocabulary

(defun magicalii--both-cases (words)
  "Return WORDS together with their upper-case forms.
MAGICAL accepts reserved words in all lower case or all upper case."
  (append words (mapcar #'upcase words)))

(defconst magicalii--keywords
  (magicalii--both-cases
   '("if" "then" "elseif" "else" "endif" "while" "do" "endwhile"
     "repeat" "until" "return" "break" "abort" "abortoff" "aborton"))
  "Control-flow reserved words.")

(defconst magicalii--operators
  (magicalii--both-cases '("and" "or" "not" "mod"))
  "Reserved words that are operators.")

(defconst magicalii--intrinsics
  (magicalii--both-cases '("size" "sqrt" "trunc" "typeof"))
  "Reserved words that are functions in expressions.")

(defconst magicalii--expression-words
  (magicalii--both-cases
   '("if" "elseif" "while" "until" "return" "and" "or" "not" "mod"))
  "Reserved words that an expression follows, not a statement.")

(defconst magicalii--builtins
  '("Acq" "CEXP" "CSschedule" "DELEXP" "RT" "RTP" "SVF" "SVP" "Svfname"
    "Svsname" "aa" "abortallacqs" "abs" "acos" "acosy" "acosyold" "acqdebug"
    "acqdequeue" "acqdisp" "acqi" "acqipctst" "acqsend" "acqstatus" "add"
    "addi" "adept" "ai" "analyze" "annotation" "ap" "aph" "aph0" "aphb"
    "aphold" "appdir" "append" "appendstr" "asin" "atan" "atan2" "atcmd"
    "auargs" "auto" "autogo" "autoname" "autoq" "autora" "autosa" "av" "av1"
    "av2" "averag" "axis" "banner" "bc" "bc2d" "beepoff" "beepon" "bgmode_is"
    "bigendian" "box" "bph" "calcECC" "calcdim" "calibxy" "canWrite" "cat"
    "cd" "cdc" "center" "chchsums" "chkname" "chmod" "clear" "clradd"
    "clrshellcnt" "cmdHistory" "cmdlineOK" "continprepare" "continread"
    "convertbruker" "convertdelta" "convertmagritek" "convertoxford"
    "convertqone" "copy" "copyf" "copystr" "cos" "cp" "cpFilesInFile"
    "create" "createparams" "ctext" "cz" "da" "data_dir" "datafit" "db" "dc"
    "dc2d" "dcon" "dconi" "dconn" "ddf" "ddff" "ddfp" "ddif" "debug"
    "decay_gen" "decc_compare" "decc_load" "decc_purge" "decc_purgewhat"
    "decc_save" "delbuf" "delem" "delete" "deleteREC" "delexpdata" "dels"
    "deltatime" "destroy" "destroygroup" "devicenames" "df" "df2d" "dfid"
    "dfid2" "dfs" "dfsa" "dfsan" "dfsh" "dfshn" "dfsn" "dfww" "dfwwn" "dg"
    "dir" "disp1Dmap" "disp3Dmap" "display" "dlalong" "do_pcss" "dosyfit"
    "dosyfitv" "downsizefid" "dpcon" "dpconn" "dpf" "dpir" "dpirN" "dps"
    "dpsn" "dpsvj" "draw" "drawxy" "dres" "ds" "ds2d" "ds2dn" "dscale"
    "dscalen" "dsn" "dsp" "dss" "dssa" "dssan" "dssh" "dsshn" "dssn" "dsww"
    "dswwn" "echo" "eleminfo" "encipher" "epi_recon" "ernst" "errlog" "exec"
    "execexp" "exists" "exp" "expactive" "expl" "exptime" "f" "fidarea"
    "fiddle" "fiddle2D" "fiddle2Dd" "fiddle2d" "fiddle2dd" "fiddlecf"
    "fiddled" "fiddleu" "fidmax" "fidproc" "files" "filesinfo" "fitspec"
    "flashc" "flip" "flush" "flush2" "flushpars" "focus" "foldcc" "foldj"
    "foldt" "format" "fp" "fr" "frameAction" "framecmd" "fread" "fsave" "ft"
    "ft1d" "ft2d" "full" "fullt" "getDataStat" "getFidName" "getFileOwner"
    "getLastData" "getMaxIndex" "getP11Dir" "getdatadim" "getdfstat"
    "getdgroup" "getdsstat" "geterror" "getfile" "getfilestat" "getlimit"
    "getll" "getmag" "getplotterpens" "getplottertype" "getreg" "getstatus"
    "gettxt" "gettype" "getvalue" "getvalue4name" "gin" "gmaplistfunc"
    "gplan" "gplan_update" "gradfit" "graphis" "graphoff" "groupcopy"
    "gxyz0fit" "gxyzfit" "gxyzmap" "gxyzmapo" "gzfit" "h2cal" "halt" "halt2"
    "help" "hidecommand" "host" "hpa" "hztomm" "ilfid" "imagefile"
    "initTclDg" "initrtvar" "input" "inset" "integ" "interact" "iplot"
    "isCSIMode" "isDataRecord" "isFDAdata" "isFDAdir" "isFDAsystem"
    "isRecUpdated" "iscmdopen" "isimagebrowser" "isvnmrj" "jEvent" "jEvent2"
    "jFunc" "jFunc2" "jMove" "jMove2" "jMove3" "jRegion" "jRegion2" "jexp"
    "jplot" "jread" "large" "lccmd" "left" "length" "lf" "liMMap"
    "listvnmrcmd" "ll2d" "llMMap" "ln" "lock" "locki" "locklc" "lookup" "lp"
    "ls" "lsfid" "macroLine" "macrocat" "macrocp" "macrodir" "macrold"
    "macrorm" "macrosyscp" "macrosysdir" "magicvars" "magnetom" "makefid"
    "makeslice" "mark" "maxpeak" "md" "menu" "mf" "mfblk" "mfclose" "mfdata"
    "mfopen" "mftrace" "mkchsums" "mkdir" "mousebuttons" "move" "mp" "mspec"
    "mstat" "mv" "ndps" "newmenu" "nextexp" "nl" "nl2" "nli" "nll" "nm"
    "noise" "numreg" "off" "on" "onCancel" "ovjCount" "p1" "p11_action"
    "p11_switchOpt" "p11datamirror" "pa" "pa1" "pacosy" "padept"
    "pannotation" "pap" "paramcopy" "pcmapapply" "pcmapclose" "pcmapgen"
    "pcmapopen" "pcon" "peak" "peak2d" "peakmin" "pen" "pexpl" "pfww" "ph"
    "ph1" "ph2" "phase_fid" "pir" "pirN" "pl" "pl2d" "plfid" "pll2d"
    "plot1Dmap" "plot3Dmap" "plotpage" "plotxy" "plww" "pmlcmd" "poptime"
    "pow" "powerfit" "ppf" "pps" "pread" "printoff" "printon" "profile_int"
    "proj" "prune" "pscale" "psgupdateoff" "psgupdateon" "purge" "pushtime"
    "putf" "puti" "putp" "puttxt" "pw" "pwd" "pwr" "pwr1" "pwr2" "quadtt" "r"
    "ra" "random" "readf1" "readfile" "readheader" "readhw" "readlk"
    "readpar" "readparam" "readpars" "readspectrum" "readstr" "real" "recon"
    "recon3D" "recon_all" "recon_mm" "recordOff" "redirect" "refresh"
    "region" "releaseConsole" "rename" "repaint" "replacetraces" "resume"
    "rfblk" "rfdata" "rftrace" "right" "rights" "rjexp" "rm" "rmdir" "rmfile"
    "rotate" "rsapply" "rtphf" "rts" "rtv" "rtx" "s" "sa" "savecolors"
    "savefdfspec" "scalefid" "selbuf" "select" "serverport" "set3dproc"
    "setButtonState" "set_mag_login" "set_node_name" "set_password"
    "set_remote_dir" "set_user_name" "setcolor" "setdgroup" "setenumeral"
    "setfont" "setfrq" "setgrid" "setgroup" "sethw" "sethwshim" "setlimit"
    "setpage" "setplotdev" "setprintdev" "setprotect" "setrtvar" "settype"
    "setvalue" "setvalue4name" "setwin" "shell" "shelli" "shim" "shimamp"
    "shimnames" "show_local_files" "show_remote_files" "showbuf"
    "showshellcnt" "sin" "sleep" "small" "solvinfo" "sortCmd" "spa" "spadd"
    "spin" "spins" "splmodprepare" "splmodread" "spmax" "spmin" "spsub"
    "sread" "string" "strstr" "sub" "substr" "svd" "svdat" "svdfit" "svphf"
    "svr" "svr_as" "svr_p" "svr_r" "svs" "svsdfd" "swrite" "systemtime" "tan"
    "tbox" "tcapply" "tcclose" "tcl" "tcopen" "tempcal" "testPart11"
    "teststr" "text" "textis" "touch" "trackCursor" "tune" "uname" "unit"
    "unixtime" "updtparam" "vnmr_unlock" "vnmrexit" "vnmrinfo" "vnmrj_close"
    "vnmrjcmd" "w" "wbs" "wdone" "werr" "wexp" "wfidproc" "wft" "wft1d"
    "wft2d" "wnt" "worst1" "write" "writeToVnmrJcmd" "writef1" "writefid"
    "writefile" "writeparam" "writespectrum" "wrspec" "wsram" "wti" "xoroff"
    "xoron" "z" "zerofillfid" "zeroneg")
  "Commands built into VnmrJ, from the command table in OpenVnmrJ.")

(defconst magicalii--keyword-regexp
  (regexp-opt magicalii--keywords 'symbols))

(defconst magicalii--operator-regexp
  (regexp-opt magicalii--operators 'symbols))

(defconst magicalii--intrinsic-regexp
  (regexp-opt magicalii--intrinsics 'symbols))

(defconst magicalii--builtin-regexp
  (regexp-opt magicalii--builtins 'symbols))

(defconst magicalii--identifier-regexp
  "\\_<[A-Za-z_][A-Za-z0-9_]*\\_>"
  "Regexp for a name that is not a local variable.")

(defconst magicalii--block-regexp
  (concat "\\_<\\(?:\\("
          (regexp-opt (magicalii--both-cases '("if" "while" "repeat")))
          "\\)\\|\\("
          (regexp-opt (magicalii--both-cases '("endif" "endwhile" "until")))
          "\\)\\)\\_>")
  "Regexp for block openers (group 1) and block closers (group 2).")

(defconst magicalii--dedent-regexp
  (concat "[ \t]*"
          (regexp-opt (magicalii--both-cases
                       '("else" "elseif" "endif" "endwhile" "until"))
                      'symbols))
  "Regexp for the start of a line that closes or continues a block.")

;;;; Syntax

(defvar magicalii-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\" "!" table)
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?` "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?$ "_" table)
    (modify-syntax-entry ?# "_" table)
    (modify-syntax-entry ?_ "_" table)
    (dolist (c '(?+ ?- ?= ?< ?> ?% ?? ?: ?,))
      (modify-syntax-entry c "." table))
    table)
  "Syntax table for `magicalii-mode'.")

;;;; Font lock

(defun magicalii--statement-start-p (pos)
  "Return non-nil if a statement can start at POS.
MAGICAL separates statements with white space only, so this looks
at the text before POS."
  (save-excursion
    (let ((ppss (syntax-ppss pos)))
      (and (zerop (nth 0 ppss))
           (not (nth 8 ppss))
           (progn
             (goto-char pos)
             (skip-chars-backward " \t")
             (or (bolp)
                 (let ((prev (char-before)))
                   (cond
                    ((memq prev '(?= ?< ?> ?+ ?- ?* ?/ ?% ?, ?: ?{ ?\\))
                     nil)
                    ((memq (char-syntax prev) '(?w ?_))
                     (not (member (buffer-substring-no-properties
                                   (save-excursion
                                     (skip-syntax-backward "w_")
                                     (point))
                                   (point))
                                  magicalii--expression-words)))
                    (t t)))))))))

(defun magicalii--next-char (pos)
  "Return the first character after POS that is not a space or tab."
  (save-excursion
    (goto-char pos)
    (skip-chars-forward " \t")
    (char-after)))

(defun magicalii--assignment-target-p (end)
  "Return non-nil if the name that ends at END receives an assignment."
  (save-excursion
    (goto-char end)
    (skip-chars-forward " \t")
    (when (eq (char-after) ?\[)
      (condition-case nil
          (forward-sexp)
        (scan-error (goto-char (line-end-position))))
      (skip-chars-forward " \t"))
    (eq (char-after) ?=)))

(defun magicalii--search (regexp predicate limit)
  "Search for REGEXP before LIMIT until PREDICATE return non-nil.
PREDICATE gets the start and end of the match."
  (let (found)
    (while (and (not found) (re-search-forward regexp limit t))
      (let ((beg (match-beginning 0))
            (end (match-end 0)))
        (setq found (save-match-data (funcall predicate beg end)))))
    found))

(defun magicalii--match-builtin (limit)
  "Find a built-in command in a command position before LIMIT."
  (magicalii--search
   magicalii--builtin-regexp
   (lambda (beg end)
     (let ((next (magicalii--next-char end)))
       (or (eq next ?\()
           (and (not (memq next '(?= ?\[ ??)))
                (magicalii--statement-start-p beg)))))
   limit))

(defun magicalii--match-assignment (limit)
  "Find a parameter that receives an assignment before LIMIT."
  (magicalii--search
   magicalii--identifier-regexp
   (lambda (beg end)
     (and (magicalii--statement-start-p beg)
          (magicalii--assignment-target-p end)))
   limit))

(defun magicalii--match-call (limit)
  "Find a macro or command call before LIMIT."
  (magicalii--search
   magicalii--identifier-regexp
   (lambda (beg end)
     (let ((next (magicalii--next-char end)))
       (or (eq next ?\()
           (and (not (memq next '(?= ?\[ ??)))
                (magicalii--statement-start-p beg)))))
   limit))

(defvar magicalii-font-lock-keywords
  `(("\\_<\\$\\(?:#\\|[0-9]+\\)\\_>" . 'magicalii-argument)
    ("\\_<\\$\\(?:\\sw\\|\\s_\\)*" . 'magicalii-local-variable)
    (,magicalii--keyword-regexp . font-lock-keyword-face)
    (,magicalii--operator-regexp . font-lock-keyword-face)
    (,magicalii--intrinsic-regexp . font-lock-builtin-face)
    (magicalii--match-builtin . font-lock-builtin-face)
    (magicalii--match-assignment . font-lock-variable-name-face)
    (magicalii--match-call . magicalii--function-call-face))
  "Font lock rules for `magicalii-mode'.")

;;;; Indentation

(defun magicalii--code-line-p ()
  "Return non-nil if the current line has code, not only comments."
  (save-excursion
    (beginning-of-line)
    (let ((end (line-end-position))
          (ppss (syntax-ppss)))
      (when (nth 8 ppss)
        (goto-char (nth 8 ppss))
        (if (nth 4 ppss)
            (forward-comment 1)
          (condition-case nil
              (forward-sexp)
            (scan-error (goto-char (point-max))))))
      (forward-comment (buffer-size))
      (< (point) end))))

(defun magicalii--continued-line-p ()
  "Return non-nil if the previous line ends with a backslash."
  (save-excursion
    (beginning-of-line)
    (and (not (bobp))
         (progn (backward-char)
                (eq (char-before) ?\\))
         (not (nth 8 (syntax-ppss (1- (point))))))))

(defun magicalii--statement-beginning ()
  "Move to the start of the line where the current statement begins."
  (beginning-of-line)
  (let (done)
    (while (not done)
      (let ((ppss (syntax-ppss)))
        (cond ((nth 8 ppss)
               (goto-char (nth 8 ppss))
               (beginning-of-line))
              ((> (nth 0 ppss) 0)
               (goto-char (nth 1 ppss))
               (beginning-of-line))
              ((magicalii--continued-line-p)
               (forward-line -1))
              (t (setq done t)))))))

(defun magicalii--block-change (beg end)
  "Return the net change of block depth from BEG to END."
  (save-excursion
    (goto-char beg)
    (let ((n 0))
      (while (re-search-forward magicalii--block-regexp end t)
        (unless (nth 8 (save-excursion (syntax-ppss (match-beginning 0))))
          (setq n (if (match-beginning 1) (1+ n) (1- n)))))
      n)))

(defun magicalii--previous-statement ()
  "Return the indentation that the line after the previous statement gets.
Return nil if there is no previous statement."
  (save-excursion
    (beginning-of-line)
    (let (found)
      (while (and (not found) (not (bobp)))
        (forward-line -1)
        (setq found (magicalii--code-line-p)))
      (when found
        (let ((end (line-end-position)))
          (magicalii--statement-beginning)
          (+ (current-indentation)
             (* magicalii-indent-offset
                (+ (magicalii--block-change (point) end)
                   (if (looking-at-p magicalii--dedent-regexp) 1 0)))))))))

(defun magicalii--calculate-indentation ()
  "Return the column for the current line, or `noindent'."
  (save-excursion
    (beginning-of-line)
    (let ((ppss (syntax-ppss))
          (case-fold-search nil))
      (cond
       ((nth 8 ppss) 'noindent)
       ((> (nth 0 ppss) 0)
        (let ((closer (save-excursion (skip-chars-forward " \t")
                                      (memq (char-after) '(?\) ?\])))))
          (goto-char (nth 1 ppss))
          (if closer
              (current-column)
            (let ((base (save-excursion (magicalii--statement-beginning)
                                        (current-indentation))))
              (forward-char)
              (skip-chars-forward " \t")
              (if (eolp)
                  (+ base magicalii-indent-offset)
                (current-column))))))
       ((magicalii--continued-line-p)
        (forward-line -1)
        (magicalii--statement-beginning)
        (+ (current-indentation) magicalii-indent-offset))
       (t
        (max 0 (- (or (magicalii--previous-statement) 0)
                  (if (looking-at-p magicalii--dedent-regexp)
                      magicalii-indent-offset
                    0))))))))

(defun magicalii-indent-line ()
  "Indent the current line as MAGICAL II code."
  (interactive)
  (let ((indent (magicalii--calculate-indentation)))
    (if (eq indent 'noindent)
        'noindent
      (let ((offset (- (current-column) (current-indentation))))
        (indent-line-to indent)
        (when (> offset 0)
          (forward-char offset))))))

(defun magicalii--electric-indent-p (_char)
  "Return non-nil after a word that closes or continues a block."
  (let ((case-fold-search nil))
    (save-excursion
      (let ((end (point)))
        (beginning-of-line)
        (and (looking-at magicalii--dedent-regexp)
             (= (match-end 0) end))))))

;;;; Commands

(defun magicalii--read-name (prompt)
  "Read a command or macro name with PROMPT, default the symbol at point."
  (let* ((default (thing-at-point 'symbol t))
         (name (read-string (if default
                                (format "%s (default %s): " prompt default)
                              (format "%s: " prompt))
                            nil nil default)))
    (if (string= name "")
        (user-error "No name given")
      name)))

(defun magicalii-describe-command (name)
  "Show the VnmrJ manual page for the command or macro NAME.
The pages come from `magicalii-manual-directory'."
  (interactive (list (magicalii--read-name "Manual entry")))
  (let ((file (expand-file-name name magicalii-manual-directory)))
    (if (file-readable-p file)
        (view-file-other-window file)
      (user-error "No manual entry for %s in %s"
                  name magicalii-manual-directory))))

(defun magicalii-find-macro (name)
  "Open the macro file NAME from `magicalii-macro-path'."
  (interactive (list (magicalii--read-name "Find macro")))
  (let ((file (locate-file name (mapcar #'expand-file-name
                                        magicalii-macro-path))))
    (if file
        (find-file file)
      (user-error "No macro %s in %s" name
                  (mapconcat #'identity magicalii-macro-path ", ")))))

(defvar magicalii-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-d") #'magicalii-describe-command)
    (define-key map (kbd "C-c C-f") #'magicalii-find-macro)
    map)
  "Keymap for `magicalii-mode'.")

;;;; Mode

;;;###autoload
(define-derived-mode magicalii-mode prog-mode "MAGICAL"
  "Major mode for MAGICAL II macros of Agilent/Varian VnmrJ.

\\{magicalii-mode-map}"
  :syntax-table magicalii-mode-syntax-table
  :group 'magicalii
  (setq-local font-lock-defaults '(magicalii-font-lock-keywords nil nil))
  (setq-local indent-line-function #'magicalii-indent-line)
  (add-hook 'electric-indent-functions #'magicalii--electric-indent-p nil t)
  (pcase magicalii-comment-style
    ('slash (setq-local comment-start "// ")
            (setq-local comment-end ""))
    (_ (setq-local comment-start "\" ")
       (setq-local comment-end " \"")))
  (setq-local comment-start-skip "\\(?:\"\\|//+\\|/\\*+\\)[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(?:\"\\|\\*+/\\)")
  (setq-local comment-use-syntax t)
  (setq-local parse-sexp-ignore-comments t))

;;;###autoload
(add-to-list 'auto-mode-alist '("/maclib/[^/]+\\'" . magicalii-mode))

(provide 'magicalii-mode)
;;; magicalii-mode.el ends here
