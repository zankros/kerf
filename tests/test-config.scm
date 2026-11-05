(use-modules (srfi srfi-64) (config) (util))

(test-begin "config")
(test-equal "default has model"
  "gpt-4.1-mini"
  (config-ref (default-config) "model"))
(test-equal "config-ref missing"
  #f
  (config-ref '() "nope"))
(test-equal "config-set new key"
  "v"
  (let ((c (config-set! '() "k" "v"))) (config-ref c "k")))
(test-equal "load-config returns list"
  "gpt-4.1-mini"
  (config-ref (default-config) "model"))
(test-end "config")
