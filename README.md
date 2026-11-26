# magicalii-mode

An Emacs major mode for MAGICAL II, the macro language of Agilent
(formerly Varian) VnmrJ and [OpenVnmrJ](https://github.com/OpenVnmrJ/OpenVnmrJ).

## Features

- Highlighting of reserved words (lower or upper case), the commands
  built into VnmrJ, macro calls, parameter assignments, local
  variables (`$x`) and macro arguments (`$0`, `$1`, ..., `$#`).
- All three comment forms: `"..."`, `// ...` and `/* ... */`.
- Both string forms: `'...'` and `` `...` ``, with backslash escapes.
- Indentation of `if`/`elseif`/`else`/`endif`, `while`/`do`/`endwhile`
  and `repeat`/`until` blocks. Closing words re-indent as you type them.
- `C-c C-d` opens the VnmrJ manual page for the command at point.
- `C-c C-f` opens the macro file for the name at point.

The syntax follows the MAGICAL lexer and grammar in OpenVnmrJ
(`src/vnmr/magic.lex.l`, `src/vnmr/magic.gram.y`). The list of
built-in commands comes from its command table (`src/vnmr/table.c`).

## Installation

Requires Emacs 25.1 or later.

### From MELPA

Add MELPA to your package archives, if it is not there yet:

```elisp
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
```

Then install with `M-x package-refresh-contents` and
`M-x package-install RET magicalii-mode RET`, or with `use-package`:

```elisp
(use-package magicalii-mode
  :ensure t)
```

### From source

From a clone of this repository:

```elisp
(use-package magicalii-mode
  :load-path "~/src/magical-ii-mode")
```

With Emacs 30 or later, `package-vc-install` can install it from GitHub:

```elisp
(package-vc-install "https://github.com/tesch1/magical-ii-mode")
```

Files in any directory named `maclib` open in `magicalii-mode`.
For other files, use `M-x magicalii-mode`, or put this on the first
line of the file:

```
" -*- mode: magicalii -*- "
```

## Customization

`M-x customize-group RET magicalii RET`:

| Option | Default | Meaning |
|---|---|---|
| `magicalii-indent-offset` | `4` | Columns per block level |
| `magicalii-comment-style` | `quote` | `quote` for `"..."` comments, `slash` for `//` |
| `magicalii-manual-directory` | `/vnmr/manual` | Location of the manual pages |
| `magicalii-macro-path` | `~/vnmrsys/maclib`, `/vnmr/maclib` | Macro search path |

## Development

```sh
make compile   # byte-compile with warnings shown
make test      # run the ERT tests
make checkdoc  # check the doc strings
make corpus    # check every macro in the maclib directories below CORPUS
```

`make corpus` opens each file in a `maclib` directory below `CORPUS`
(default `../OpenVnmrJ/src`) in the mode, without changing it. It
runs font lock and indentation, and reports each file that has
unclosed strings, comments or parentheses, unbalanced blocks,
unstable indentation, or a Lisp error. For example:

```sh
make corpus CORPUS=~/vnmrsys
```

## License

GNU General Public License, version 3 or later. See [LICENSE](LICENSE).
