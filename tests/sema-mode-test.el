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

(defun sema-test--face-at (source offset)
  "Return the font-lock face at OFFSET in SOURCE."
  (with-temp-buffer
    (insert source)
    (sema-mode)
    (font-lock-ensure)
    (get-text-property (1+ offset) 'face)))

(ert-deftest sema-regex-literal-has-dedicated-face ()
  (dolist (literal '("#\"\\d+\"" "#\"\\\\\"" "#\"\\\"[^\\\"]+\\\"\""))
    (let ((source (concat "(regex/match? " literal " text)")))
      (dolist (offset (number-sequence 14 (1- (+ 14 (length literal)))))
        (should (eq (sema-test--face-at source offset) 'sema-regex-face))))))

(ert-deftest sema-regex-builtins-use-builtin-face ()
  (dolist (name '("regex/match?" "regex/match" "regex/find-all"
                  "regex/replace" "regex/replace-all" "regex/split"))
    (should (eq (sema-test--face-at (concat "(" name " #\"x\" text)") 1)
                'font-lock-builtin-face))))

(provide 'sema-mode-test)

(ert-deftest sema-recognizes-complete-hash-booleans ()
  (with-temp-buffer
    (sema-mode)
    (insert "(list #t #f #true #false #truex)")
    (font-lock-ensure)
    (dolist (literal '("#t" "#f" "#true" "#false"))
      (goto-char (point-min))
      (search-forward (concat literal " "))
      (should (eq (get-text-property (- (point) 2) 'face)
                  'font-lock-constant-face)))
    (goto-char (point-min))
    (search-forward "#truex")
    (should-not (eq (get-text-property (1- (point)) 'face)
                    'font-lock-constant-face))))

(ert-deftest sema-does-not-hide-unsupported-block-comments ()
  (with-temp-buffer
    (sema-mode)
    (insert "#| unsupported |#")
    (should-not (nth 4 (syntax-ppss 5)))))

(ert-deftest sema-workflow-has-three-distinguished-arguments ()
  (with-temp-buffer
    (sema-mode)
    (insert "(defworkflow name\n\"doc\"\n{}\n(foo))")
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string)
                   "(defworkflow name\n    \"doc\"\n    {}\n  (foo))"))))

(ert-deftest sema-indents-terminal-and-binding-macro-bodies ()
  (dolist (form '("term/with-bracketed-paste" "term/with-focus-events"
                  "term/with-kitty-keys"))
    (with-temp-buffer
      (sema-mode)
      (insert "(" form "\n(foo)\n(bar))")
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) (concat "(" form "\n  (foo)\n  (bar))")))))
  (dolist (form '("parameterize" "dotimes" "for-range"))
    (with-temp-buffer
      (sema-mode)
      (insert "(" form " (x 1)\n(foo))")
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) (concat "(" form " (x 1)\n  (foo))"))))))
;;; sema-mode-test.el ends here
