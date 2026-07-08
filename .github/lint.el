;;; lint.el --- CI: run package-lint, fail only on errors -*- lexical-binding: t; -*-

;;; Commentary:

;; Installs package-lint from MELPA and lints the files passed on the
;; command line.  All findings are printed; the process exits non-zero
;; only when package-lint reports an *error*.  Warnings are tolerated on
;; purpose — e.g. the intentional `with-eval-after-load' eglot
;; registration in sema-mode.el, which MELPA reviewers routinely accept.
;;
;; Usage:  emacs -Q --batch -l .github/lint.el sema-mode.el

;;; Code:

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(package-refresh-contents)
(package-install 'package-lint)
(require 'package-lint)

(let ((had-error nil))
  (dolist (file command-line-args-left)
    (with-current-buffer (find-file-noselect file)
      (dolist (issue (package-lint-buffer))
        (let ((line (nth 0 issue))
              (col  (nth 1 issue))
              (type (nth 2 issue))
              (msg  (nth 3 issue)))
          (message "%s:%d:%d: %s: %s" file line col type msg)
          (when (eq type 'error)
            (setq had-error t))))))
  (kill-emacs (if had-error 1 0)))

;;; lint.el ends here
