(define-module (kerf util)
  #:use-module (srfi srfi-13)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 textual-ports)
  #:export (home-dir strip-trailing-slash
            shell-quote truncate-str dirname-of
            read-file* write-file* ensure-dir))

(define (home-dir)
  (or (getenv "HOME") "/"))

(define (strip-trailing-slash s)
  (let loop ((n (string-length s)))
    (if (and (> n 1) (char=? (string-ref s (- n 1)) #\/))
        (loop (- n 1))
        (substring s 0 n))))

(define (shell-quote s)
  (string-append "'"
                 (string-join (string-split s #\') "'\\''")
                 "'"))

(define (truncate-str s n)
  (if (> (string-length s) n)
      (string-append (substring s 0 n) "...")
      s))

(define (dirname-of path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) ".")
      ((char=? (string-ref path i) #\/)
       (if (= i 0) "/" (substring path 0 i)))
      (else (loop (- i 1))))))

(define (ensure-dir path)
  (unless (file-exists? path)
    (system* "mkdir" "-p" path)))

(define (read-file* path)
  (call-with-input-file path get-string-all))

(define (write-file* path content)
  (ensure-dir (dirname-of path))
  (call-with-output-file path
    (lambda (p)
      (set-port-encoding! p "UTF-8")
      (display content p))))
