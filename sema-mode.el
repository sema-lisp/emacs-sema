;;; sema-mode.el --- Major mode for editing Sema files -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Helge Sverre

;; Author: Helge Sverre <helge.sverre@gmail.com>
;; Assisted-by: Claude:claude-opus-4-8
;; URL: https://github.com/sema-lisp/emacs-sema
;; Homepage: https://sema-lang.com
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: languages, lisp

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A major mode for editing Sema (.sema) files — a Lisp dialect with
;; first-class LLM primitives.  Provides syntax highlighting, indentation,
;; and REPL integration, plus LSP hookup via eglot or lsp-mode (`sema lsp').
;;
;; Install from MELPA:
;;   M-x package-install RET sema-mode
;;
;; Or from source:
;;   (add-to-list 'load-path "/path/to/emacs-sema")
;;   (require 'sema-mode)
;;
;; If you use eglot, register Sema's language server (`sema lsp') so that
;; `M-x eglot' starts it in Sema buffers:
;;
;;   (with-eval-after-load 'eglot #'sema-register-with-eglot)
;;
;; For automatic startup, also add `eglot-ensure' to the mode hook:
;;
;;   (add-hook 'sema-mode-hook #'eglot-ensure)
;;
;; Homepage: https://sema-lang.com
;; Source:   https://github.com/sema-lisp/emacs-sema

;;; Code:

(require 'lisp-mode)
(require 'comint)

;; ── Customization ──────────────────────────────────────────────────────

(defgroup sema nil
  "Major mode for Sema, a Lisp with LLM primitives."
  :group 'languages
  :prefix "sema-")

(defcustom sema-program "sema"
  "Path to the Sema interpreter executable."
  :type 'string
  :group 'sema)

;; ── Syntax table ───────────────────────────────────────────────────────

(defvar sema-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Semicolon starts a comment, newline ends it
    (modify-syntax-entry ?\; "<" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Double quotes for strings
    (modify-syntax-entry ?\" "\"" table)
    ;; Backslash is escape
    (modify-syntax-entry ?\\ "\\" table)
    ;; Parentheses
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    ;; Characters that are part of symbols
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?- "_" table)
    (modify-syntax-entry ?/ "_" table)
    (modify-syntax-entry ?? "_" table)
    (modify-syntax-entry ?! "_" table)
    (modify-syntax-entry ?* "_" table)
    (modify-syntax-entry ?+ "_" table)
    (modify-syntax-entry ?< "_" table)
    (modify-syntax-entry ?> "_" table)
    (modify-syntax-entry ?= "_" table)
    (modify-syntax-entry ?: "_" table)
    ;; Block comments: #| ... |#
    (modify-syntax-entry ?# "_ 14b" table)
    (modify-syntax-entry ?| "_ 23b" table)
    ;; Quote-like prefixes for proper sexp handling
    (modify-syntax-entry ?' "'" table)
    (modify-syntax-entry ?` "'" table)
    (modify-syntax-entry ?, "'" table)
    table)
  "Syntax table for `sema-mode'.")

;; ── Font-lock (syntax highlighting) ────────────────────────────────────

(defvar sema-special-forms
  '("define" "defun" "lambda" "fn" "if" "cond" "case" "when" "unless"
    "let" "let*" "letrec" "begin" "do" "and" "or"
    "set!" "quote" "quasiquote" "unquote" "unquote-splicing"
    "define-record-type" "defmacro" "defagent" "deftool"
    "try" "catch" "throw"
    "import" "module" "export" "load"
    "delay" "force" "eval" "macroexpand" "with-budget"
    "prompt" "message"
    "else")
  "Sema special forms and core keywords.")

(defvar sema-builtin-functions
  '(;; Threading macros
    "->" "->>" "as->"
    ;; Higher-order
    "map" "filter" "foldl" "foldr" "reduce" "for-each" "apply"
    ;; LLM / Agent
    "conversation/new" "conversation/say"
    "conversation/messages" "conversation/last-reply" "conversation/fork"
    "conversation/add-message" "conversation/model"
    "llm/complete" "llm/chat" "llm/stream" "llm/send"
    "llm/extract" "llm/classify" "llm/batch" "llm/pmap"
    "llm/embed" "llm/auto-configure" "llm/configure"
    "llm/set-budget" "llm/budget-remaining"
    "llm/define-provider" "llm/last-usage" "llm/session-usage"
    "llm/similarity" "llm/clear-budget"
    "llm/configure-embeddings" "llm/current-provider" "llm/list-providers"
    "llm/pricing-status" "llm/reset-usage" "llm/set-default" "llm/set-pricing"
    "prompt/append" "prompt/messages" "prompt/set-system"
    "message/role" "message/content"
    "agent/run" "agent/max-turns" "agent/model"
    "agent/name" "agent/system" "agent/tools"
    ;; Embedding functions
    "embedding/->list" "embedding/length"
    "embedding/list->embedding" "embedding/ref"
    ;; Tool query functions
    "tool/name" "tool/description" "tool/parameters"
    ;; I/O
    "display" "print" "println" "newline" "format"
    "read" "read-line" "read-many"
    "print-error" "println-error" "read-stdin"
    "not" "error"
    ;; Lists
    "list" "cons" "car" "cdr" "first" "rest" "nth"
    "append" "reverse" "length" "null?" "list?" "member"
    "vector" "sort" "sort-by" "take" "drop" "zip" "flatten"
    "range" "make-list" "flat-map" "take-while" "drop-while"
    "every" "any" "partition" "iota" "last"
    ;; ca*r/cd*r variants
    "caar" "cadr" "cdar" "cddr"
    "caaar" "caadr" "cadar" "caddr" "cdaar" "cdadr" "cddar" "cdddr"
    ;; list/* namespaced functions
    "list/chunk" "list/dedupe" "list/drop-while" "list/group-by"
    "list/index-of" "list/interleave" "list/max" "list/min"
    "list/pick" "list/repeat" "list/shuffle" "list/split-at"
    "list/sum" "list/take-while" "list/unique"
    "list->bytevector" "list->string" "list->vector"
    ;; Additional list functions
    "assq" "assv" "flatten-deep" "frequencies" "interpose" "vector->list"
    ;; Strings
    "string-append" "string/join" "string/split"
    "string/trim" "string/upper" "string/lower"
    "string/contains?" "string/starts-with?" "string/ends-with?"
    "string/replace" "substring" "string-length" "string-ref"
    "string/capitalize" "string/empty?" "string/index-of"
    "string/reverse" "string/repeat"
    "string/pad-left" "string/pad-right"
    "str" "string->keyword" "keyword->string"
    "string->char" "string->float" "string->list" "string->utf8"
    "string-ci=?"
    "string/byte-length" "string/chars" "string/codepoints"
    "string/foldcase" "string/from-codepoints" "string/last-index-of"
    "string/map" "string/normalize" "string/number?"
    "string/title-case" "string/trim-left" "string/trim-right"
    ;; Char functions
    "char->integer" "char->string" "integer->char"
    "char-alphabetic?" "char-ci<?" "char-ci<=?" "char-ci=?"
    "char-ci>?" "char-ci>=?" "char-downcase" "char-lower-case?"
    "char-numeric?" "char-upcase" "char-upper-case?"
    "char-whitespace?" "char<?" "char<=?" "char=?" "char>?" "char>=?"
    ;; Math
    "abs" "min" "max" "round" "floor" "ceiling"
    "sqrt" "expt" "math/remainder" "modulo" "math/gcd" "math/lcm"
    "pow" "log" "sin" "cos" "ceil" "int" "float" "truncate" "mod" "%"
    "math/pow" "math/tan" "math/random" "math/random-int"
    "math/clamp" "math/sign" "math/exp" "math/log10" "math/log2"
    "math/acos" "math/asin" "math/atan" "math/atan2"
    "math/cosh" "math/degrees->radians" "math/infinite?" "math/lerp"
    "math/map-range" "math/nan?" "math/quotient"
    "math/radians->degrees" "math/sinh" "math/tanh"
    ;; Hash maps
    "hash-map" "get" "assoc" "dissoc" "keys" "vals"
    "contains?" "merge" "count" "empty?"
    ;; map/* functions
    "map/entries" "map/filter" "map/from-entries"
    "map/map-keys" "map/map-vals" "map/select-keys" "map/update"
    ;; hashmap/* functions
    "hashmap/new" "hashmap/get" "hashmap/assoc"
    "hashmap/keys" "hashmap/contains?" "hashmap/to-map"
    ;; Predicates
    "number?" "string?" "symbol?" "pair?" "boolean?"
    "procedure?" "char?" "vector?" "map?" "zero?"
    "positive?" "negative?" "equal?" "eq?" "eqv?"
    "integer?" "float?" "keyword?" "nil?" "fn?" "record?" "promise?"
    "bool?" "bytevector?" "even?" "odd?"
    "agent?" "conversation?" "message?" "prompt?" "tool?" "promise-forced?"
    "type"
    ;; Type conversions
    "string->number" "number->string" "string->symbol" "symbol->string"
    ;; File I/O
    "file/read" "file/write" "file/append" "file/exists?"
    "file/delete" "file/list"
    "file/rename" "file/copy" "file/info" "file/mkdir"
    "file/is-directory?" "file/is-file?"
    "file/read-lines" "file/write-lines"
    "file/fold-lines" "file/for-each-line" "file/is-symlink?"
    ;; Path functions
    "path/absolute" "path/basename" "path/dirname"
    "path/extension" "path/join"
    ;; JSON
    "json/decode" "json/encode" "json/encode-pretty"
    ;; HTTP
    "http/get" "http/post" "http/put" "http/delete"
    "http/request"
    ;; Regex
    "regex/match?" "regex/match" "regex/find-all"
    "regex/replace" "regex/replace-all" "regex/split"
    ;; Crypto
    "uuid/v4" "base64/encode" "base64/decode"
    "hash/md5" "hash/sha256" "hash/hmac-sha256"
    ;; DateTime
    "time/now" "time/format" "time/parse"
    "time/date-parts" "time/add" "time/diff"
    ;; CSV
    "csv/parse" "csv/parse-maps" "csv/encode"
    ;; Bitwise
    "bit/and" "bit/or" "bit/xor" "bit/not"
    "bit/shift-left" "bit/shift-right"
    ;; Terminal functions
    "term/style" "term/strip" "term/rgb"
    "term/spinner-start" "term/spinner-stop" "term/spinner-update"
    ;; Bytevector functions
    "bytevector" "make-bytevector" "bytevector-length"
    "bytevector-u8-ref" "bytevector-u8-set!" "bytevector-copy"
    "bytevector-append" "bytevector->list" "utf8->string"
    ;; System
    "env" "shell" "exit" "time-ms" "sleep"
    "sys/args" "sys/cwd" "sys/platform" "sys/set-env" "sys/env-all"
    "sys/arch" "sys/elapsed" "sys/home-dir" "sys/hostname"
    "sys/interactive?" "sys/os" "sys/pid" "sys/temp-dir"
    "sys/tty" "sys/user" "sys/which"
    ;; Meta
    "gensym")
  "Sema built-in standard library functions.")

(defvar sema-font-lock-keywords
  (let ((special-forms-re
         (concat "(" (regexp-opt sema-special-forms 'symbols)))
        (builtins-re
         (concat "(" (regexp-opt sema-builtin-functions 'symbols))))
    `(;; Special forms — after opening paren
      (,special-forms-re 1 font-lock-keyword-face)
      ;; Builtin functions — after opening paren
      (,builtins-re 1 font-lock-builtin-face)
      ;; Keyword literals :foo
      ("\\_<:\\(?:\\sw\\|\\s_\\)+" . font-lock-constant-face)
      ;; Boolean literals
      ("\\_<#[tf]\\_>" . font-lock-constant-face)
      ("\\_<\\(?:true\\|false\\)\\_>" . font-lock-constant-face)
      ;; Character literals #\space #\a etc.
      ("\\_<#\\\\\\(?:space\\|newline\\|tab\\|return\\|nul\\|alarm\\|backspace\\|delete\\|escape\\)\\_>"
       . font-lock-constant-face)
      ("\\_<#\\\\.\\_>" . font-lock-constant-face)
      ;; nil
      ("\\_<nil\\_>" . font-lock-constant-face)
      ;; Numeric literals
      ("\\_<-?[0-9]+\\(?:\\.[0-9]+\\)?\\_>" . font-lock-constant-face)
      ;; define/defun name
      ("(\\(?:define\\|defun\\)\\s-+(?\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-function-name-face)
      ;; defmacro name
      ("(defmacro\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-function-name-face)
      ;; defagent name
      ("(defagent\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-function-name-face)
      ;; deftool name
      ("(deftool\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-function-name-face)
      ;; define-record-type name
      ("(define-record-type\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-type-face)
      ;; set! target name
      ("(set!\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
       1 font-lock-variable-name-face)))
  "Font-lock keywords for `sema-mode'.")

;; ── Indentation ────────────────────────────────────────────────────────

(defvar sema--indent-1-forms
  '(let let* letrec if case try when unless with-budget module
    set! import delay throw prompt message
    define defun lambda fn defmacro defagent deftool define-record-type)
  "Sema forms with one distinguished argument (indent method 1).")

(defvar sema--indent-0-forms
  '(do begin cond)
  "Sema forms with no distinguished argument (indent method 0).")

(defun sema--indent-function (indent-point state)
  "Sema-specific indentation function.
INDENT-POINT and STATE are as for the function `lisp-indent-function',
which this function falls back to after checking Sema-specific forms."
  (let* ((normal-indent (current-column))
         (containing-sexp (nth 1 state)))
    (when containing-sexp
      (goto-char (1+ containing-sexp))
      (when (looking-at "\\(?:\\sw\\|\\s_\\)+")
        (let* ((sym (intern-soft (match-string 0)))
               (indent (cond ((memq sym sema--indent-1-forms) 1)
                             ((memq sym sema--indent-0-forms) 0))))
          (when indent
            (lisp-indent-specform indent state indent-point normal-indent)))))))

;; ── REPL ───────────────────────────────────────────────────────────────

(defun sema-repl ()
  "Start an inferior Sema REPL process."
  (interactive)
  (let ((buffer (make-comint "sema" sema-program)))
    (pop-to-buffer buffer)
    (setq-local comint-prompt-regexp "^sema> *")))

(defun sema-send-region (start end)
  "Send the region between START and END to the Sema REPL."
  (interactive "r")
  (let ((proc (get-buffer-process "*sema*")))
    (unless proc
      (error "No Sema REPL running — start one with M-x sema-repl"))
    (comint-send-string proc (buffer-substring-no-properties start end))
    (comint-send-string proc "\n")))

(defun sema-send-last-sexp ()
  "Send the sexp before point to the Sema REPL."
  (interactive)
  (sema-send-region (save-excursion (backward-sexp) (point)) (point)))

(defun sema-send-buffer ()
  "Send the entire buffer to the Sema REPL."
  (interactive)
  (sema-send-region (point-min) (point-max)))

(defun sema-run-file ()
  "Run the current file with the Sema interpreter."
  (interactive)
  (unless buffer-file-name
    (error "Buffer is not visiting a file"))
  (compile (concat sema-program " " (shell-quote-argument buffer-file-name))))

;; ── Keymap ─────────────────────────────────────────────────────────────

(defvar sema-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'sema-repl)
    (define-key map (kbd "C-c C-r") #'sema-send-region)
    (define-key map (kbd "C-c C-e") #'sema-send-last-sexp)
    (define-key map (kbd "C-c C-b") #'sema-send-buffer)
    (define-key map (kbd "C-c C-l") #'sema-run-file)
    map)
  "Keymap for `sema-mode'.")

;; ── Major mode definition ──────────────────────────────────────────────

;; Declared for the byte-compiler: the mode sets this buffer-locally so
;; electric-pair-mode pairs Sema brackets, but `elec-pair' may not be loaded
;; at compile time (Emacs < 29 under `emacs -Q').
(defvar electric-pair-pairs)

;;;###autoload
(define-derived-mode sema-mode prog-mode "Sema"
  "Major mode for editing Sema files.

Sema is a Lisp dialect with first-class LLM primitives.
See https://sema-lang.com for documentation.

\\{sema-mode-map}"
  :syntax-table sema-mode-syntax-table
  :group 'sema
  (setq-local comment-start "; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")
  (setq-local indent-line-function #'lisp-indent-line)
  (setq-local lisp-indent-function #'sema--indent-function)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local font-lock-defaults '(sema-font-lock-keywords))
  (setq-local electric-pair-pairs '((?\( . ?\))
                                     (?\[ . ?\])
                                     (?\{ . ?\})
                                     (?\" . ?\")))
  (setq-local imenu-generic-expression
              '(("Functions" "^\\s-*(defun\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Functions" "^\\s-*(define\\s-+(\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Variables" "^\\s-*(define\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Macros" "^\\s-*(defmacro\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Agents" "^\\s-*(defagent\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Tools" "^\\s-*(deftool\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
                ("Records" "^\\s-*(define-record-type\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sema\\'" . sema-mode))

;; ── LSP via eglot ─────────────────────────────────────────────────────────

(defvar eglot-server-programs)

;;;###autoload
(defun sema-register-with-eglot ()
  "Register Sema's language server (`sema lsp') with eglot.
After calling this, `M-x eglot' in a Sema buffer starts the server.
Add it to your configuration so registration stays explicit:

  (with-eval-after-load \\='eglot #\\='sema-register-with-eglot)

For automatic startup, also add `eglot-ensure' to `sema-mode-hook'."
  (add-to-list 'eglot-server-programs '(sema-mode . ("sema" "lsp"))))

(provide 'sema-mode)

;;; sema-mode.el ends here
