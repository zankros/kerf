(use-modules (srfi srfi-64) (util))
(test-begin "util")
(test-equal "shell-quote"
  "'a'\\''b'"
  (shell-quote "a'b"))
(test-equal "truncate"
  "abc..."
  (truncate-str "abcdef" 3))
(test-equal "dirname"
  "/tmp"
  (dirname-of "/tmp/x"))
(test-end "util")
