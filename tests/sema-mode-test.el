;;; sema-mode-test.el --- Tests for sema-mode -*- lexical-binding: t; -*-

(require 'ert)
(require 'sema-mode)

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
;;; sema-mode-test.el ends here
