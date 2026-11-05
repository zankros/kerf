(define-module (config)
  #:use-module (json)
  #:use-module (util)
  #:export (config-dir config-path default-config load-config save-config
            config-ref config-set!))

(define (config-dir)
  (string-append
   (or (getenv "XDG_CONFIG_HOME")
       (string-append (home-dir) "/.config"))
   "/kerf"))

(define (config-path)
  (string-append (config-dir) "/config.json"))

(define (default-config)
  `(("base_url" . "https://api.openai.com/v1")
    ("model" . "gpt-4.1-mini")
    ("api_key_env" . "KERF_API_KEY")
    ("api_key" . "")
    ("workdir" . ,(getcwd))
    ("auto_approve" . #f)
    ("max_steps" . 16)
    ("timeout" . 300)
    ("temperature" . 0.2)
    ("tool_mode" . "auto")
    ("theme" . "kerf")
    ("servers" . #())
    ("active_server" . "")))

(define (config-ref cfg key)
  (let ((p (assoc key cfg)))
    (if p
        (cdr p)
        (let ((d (assoc key (default-config))))
          (if d (cdr d) #f)))))

(define (merge-config defaults loaded)
  (let* ((merged
          (map (lambda (p)
                 (let ((q (assoc (car p) loaded)))
                   (if q (cons (car p) (cdr q)) p)))
               defaults)))
    (append merged
            (filter (lambda (p) (not (member (car p) (map car defaults))))
                    loaded))))

(define (config-set! cfg key val)
  (let ((p (assoc key cfg)))
    (if p
        (set-cdr! p val)
        (if (null? cfg)
            (set! cfg (list (cons key val)))
            (set-cdr! (last-pair cfg) (list (cons key val))))))
  cfg)

(define (load-config)
  (let ((path (config-path)))
    (if (file-exists? path)
        (catch #t
          (lambda ()
            (let ((cfg (json-read-string (read-file* path))))
              (if (list? cfg)
                  (merge-config (default-config) cfg)
                  (default-config))))
          (lambda _
            (default-config)))
        (begin
          (ensure-dir (config-dir))
          (write-file* path (json-write-string (default-config)))
          (default-config)))))

(define (save-config cfg)
  (ensure-dir (config-dir))
  (write-file* (config-path) (json-write-string cfg))
  cfg)
