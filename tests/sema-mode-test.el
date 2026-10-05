;;; sema-mode-test.el --- Tests for sema-mode -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'sema-mode)

(ert-deftest sema-eglot-registration-uses-custom-program ()
  (skip-unless (require 'eglot nil t))
  (let ((eglot-server-programs nil)
        (sema-program "/opt/Sema App/bin/sema"))
    (sema-register-with-eglot)
    (let ((contact (cdr (assq 'sema-mode eglot-server-programs))))
      (should (equal (funcall contact nil nil)
                     '("/opt/Sema App/bin/sema" "lsp"))))))

(ert-deftest sema-run-file-quotes-the-program-and-file ()
  (let ((sema-program "/opt/Sema App/bin/sema")
        command)
    (with-temp-buffer
      (setq buffer-file-name "/tmp/my file.sema")
      (cl-letf (((symbol-function 'compile)
                 (lambda (value) (setq command value))))
        (sema-run-file)))
    (should (equal command
                   (concat (shell-quote-argument sema-program) " "
                           (shell-quote-argument "/tmp/my file.sema"))))))

(ert-deftest sema-indents-body-macros ()
  (with-temp-buffer
    (sema-mode)
    (insert "(guard (e (else nil))\n(foo))\n(with-open (x y)\n(foo))")
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string)
                   "(guard (e (else nil))\n  (foo))\n(with-open (x y)\n  (foo))"))))

(ert-deftest sema-highlights-the-full-numeric-tower ()
  (with-temp-buffer
    (sema-mode)
    (insert "+2e3 1/2 3+4i +i #xFF #e#xFF 0x1F")
    (font-lock-ensure)
    (dolist (literal '("+2e3" "1/2" "3+4i" "+i" "#xFF" "#e#xFF"))
      (goto-char (point-min))
      (search-forward literal)
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-constant-face)))
    (goto-char (point-min))
    (search-forward "0x1F")
    (should-not (eq (get-text-property (1- (point)) 'face)
                    'font-lock-constant-face))))

(ert-deftest sema-highlights-documented-builtins ()
  (with-temp-buffer
    (sema-mode)
    (insert "(bytes/length x) (async/with-timeout 1 f) "
            "(path/canonicalize x) (db/open x) (workflow/mcp-handle x)")
    (font-lock-ensure)
    (dolist (name '("bytes/length" "async/with-timeout" "path/canonicalize"
                    "db/open" "workflow/mcp-handle"))
      (goto-char (point-min))
      (search-forward name)
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-builtin-face)))))

(provide 'sema-mode-test)

;;; sema-mode-test.el ends here
