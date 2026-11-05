(use-modules (srfi srfi-64) (json))

(test-begin "json")

(test-equal "roundtrip string"
  "hello"
  "hello")

(test-equal "parse object"
  42
  (json-get (json-read-string "{\"a\":42}") "a"))

(test-equal "write null"
  "null"
  (json-write-string 'null))

(test-equal "empty array"
  "[]"
  (json-write-string '()))

(test-equal "nested array"
  2
  (vector-length (json-get (json-read-string "{\"a\":[1,2]}") "a")))

(test-end "json")
