<div align="center">

<img src="https://sema-lang.com/logo.svg" alt="Sema" height="64">

# Sema for Emacs

**[Sema](https://sema-lang.com) major mode for [Emacs](https://www.gnu.org/software/emacs/)** — a Lisp with first-class LLM primitives.

[![CI](https://img.shields.io/github/actions/workflow/status/sema-lisp/emacs-sema/ci.yml?branch=main&label=CI&logo=github)](https://github.com/sema-lisp/emacs-sema/actions)
[![License](https://img.shields.io/github/license/sema-lisp/emacs-sema?color=c8a855)](LICENSE)
[![Website](https://img.shields.io/badge/website-sema--lang.com-c8a855)](https://sema-lang.com)

</div>

Syntax highlighting, Lisp-aware indentation, and an interactive REPL for editing `.sema` files, with optional LSP support.

## Install

### MELPA

> The MELPA recipe (`melpa-recipe`) is pending acceptance. Until it lands, use the from-source install below.

Once available on [MELPA](https://melpa.org):

```elisp
;; M-x package-install RET sema-mode
(package-install 'sema-mode)
```

With `use-package`:

```elisp
(use-package sema-mode
  :ensure t
  :mode "\\.sema\\'")
```

### From source

Clone the repo and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-sema")
(require 'sema-mode)
```

Or, on Emacs 29+, install straight from GitHub with `use-package :vc`:

```elisp
(use-package sema-mode
  :vc (:url "https://github.com/sema-lisp/emacs-sema" :rev :newest)
  :mode "\\.sema\\'")
```

Doom Emacs — in `packages.el`:

```elisp
(package! sema-mode
  :recipe (:host github :repo "sema-lisp/emacs-sema"))
```

## Features

- **Syntax highlighting** — special forms, standard-library builtins (including the `llm/*`, `agent/*`, `conversation/*`, and `tool/*` primitives), keyword literals (`:foo`), booleans (`#t`/`#f`/`true`/`false`), `nil`, character literals, numbers, strings, and `;` / `#| ... |#` comments.
- **Lisp-aware indentation** — Sema-specific indent rules layered over `lisp-mode` indentation.
- **REPL integration** — start an inferior `sema` REPL and send the region, last sexp, or whole buffer to it.
- **imenu** — navigate functions, variables, macros, agents, tools, and record types.
- **Electric pairs** — auto-close `()`, `[]`, `{}`, and `""`.
- **LSP hookup** — recipes below wire the mode to `sema lsp` via eglot or lsp-mode.

## Requirements

- **Emacs 25.1 or newer.**
- **The `sema` binary** on your `PATH` for the REPL, `sema-run-file`, and LSP. Install it from the [Sema project](https://github.com/HelgeSverre/sema) (`cargo install sema`). Point `sema-program` at a non-default location if needed:

  ```elisp
  (setq sema-program "/path/to/sema")
  ```

## Key Bindings

| Key       | Command               | Description                      |
| --------- | --------------------- | -------------------------------- |
| `C-c C-z` | `sema-repl`           | Start or switch to the Sema REPL |
| `C-c C-e` | `sema-send-last-sexp` | Send sexp before point to REPL   |
| `C-c C-r` | `sema-send-region`    | Send selected region to REPL     |
| `C-c C-b` | `sema-send-buffer`    | Send entire buffer to REPL       |
| `C-c C-l` | `sema-run-file`       | Run current file with `sema`     |

## LSP Support

Sema ships with a built-in language server (`sema lsp`) providing completions,
hover docs, go-to-definition, find references, rename, signature help,
diagnostics, document symbols, and code lens (run expressions).

### eglot (built-in since Emacs 29)

```elisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(sema-mode . ("sema" "lsp"))))
```

Then run `M-x eglot` in a `.sema` buffer.

### lsp-mode

```elisp
(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration '(sema-mode . "sema"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("sema" "lsp"))
    :activation-fn (lsp-activate-on "sema")
    :server-id 'sema-lsp)))
```

> The Sema LSP server also emits a custom `sema/evalResult` notification for
> inline evaluation results, which requires a custom client handler — see the
> Sema documentation for details.

## Submitting to MELPA (maintainer note)

The ready-to-submit recipe lives in [`melpa-recipe`](./melpa-recipe). To publish,
open a PR against [melpa/melpa](https://github.com/melpa/melpa) adding it as
`recipes/sema-mode`. Lint locally first:

```bash
emacs -Q --batch -f batch-byte-compile sema-mode.el
emacs -Q --batch -l package-lint -f package-lint-batch-and-exit sema-mode.el
emacs -Q --batch --eval '(checkdoc-file "sema-mode.el")'
```

## Links

- **Website** — [sema-lang.com](https://sema-lang.com)
- **Playground** — [sema.run](https://sema.run)
- **Documentation** — [sema-lang.com/docs](https://sema-lang.com/docs/)
- **Grammar** — [tree-sitter-sema](https://github.com/sema-lisp/tree-sitter-sema)
- **Repository** — [sema-lisp/emacs-sema](https://github.com/sema-lisp/emacs-sema)

## License

[MIT](LICENSE) © [Helge Sverre](https://github.com/HelgeSverre)
