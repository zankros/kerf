(define-module (kerf tools)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-13)
  #:use-module (kerf json)
  #:use-module (kerf util)
  #:use-module (kerf config)
  #:export (tool-definitions execute-tool reset-tools!))

(define (prop type desc)
  `(("type" . ,type) ("description" . ,desc)))

(define (fn-schema name desc props required)
  `(("type" . "function")
    ("function" .
     (("name" . ,name)
      ("description" . ,desc)
      ("parameters" .
       (("type" . "object")
        ("properties" . ,props)
        ("required" . ,(list->vector required))))))))

(define (tool-definitions)
  (vector
   (fn-schema
    "bash"
    "Run a shell command in the working directory. Returns combined stdout/stderr and the exit code."
    (list (cons "command" (prop "string" "Shell command to run."))
          (cons "timeout" (prop "number" "Seconds before the command is killed. Default 120.")))
    '("command"))
   (fn-schema
    "read"
    "Read a text file. Returns numbered lines."
    (list (cons "path" (prop "string" "File path, relative to the working directory or absolute."))
          (cons "offset" (prop "number" "First line to read, 1-based."))
          (cons "limit" (prop "number" "Maximum number of lines to read.")))
    '("path"))
   (fn-schema
    "write"
    "Create or overwrite a file. Read an existing file before replacing it."
    (list (cons "path" (prop "string" "File path."))
          (cons "content" (prop "string" "Full file content.")))
    '("path" "content"))
   (fn-schema
    "edit"
    "Replace one exact, unique string in a file. Use read first."
    (list (cons "path" (prop "string" "File path."))
          (cons "old_string" (prop "string" "Exact text to replace. Must occur once."))
          (cons "new_string" (prop "string" "Replacement text.")))
    '("path" "old_string" "new_string"))
   (fn-schema
    "list"
    "List a directory. Directories end with a slash."
    (list (cons "path" (prop "string" "Directory path. Default is the working directory.")))
    '())
   (fn-schema
    "grep"
    "Search file contents with ripgrep-style results. Use include to limit file types."
    (list (cons "pattern" (prop "string" "Regular expression to search for."))
          (cons "path" (prop "string" "File or directory. Default is the working directory."))
          (cons "include" (prop "string" "Glob filter such as *.scm."))
          (cons "limit" (prop "number" "Maximum matching lines. Default 200.")))
    '("pattern"))
   (fn-schema
    "glob"
    "Find files by shell glob. Supports ** for recursive matching."
    (list (cons "pattern" (prop "string" "Glob pattern such as **/*.scm."))
          (cons "path" (prop "string" "Base directory. Default is the working directory.")))
    '("pattern"))
   (fn-schema
    "patch"
    "Apply a unified diff to files in the working directory."
    (list (cons "patch" (prop "string" "Unified diff text.")))
    '("patch"))
   (fn-schema
    "webfetch"
    "Fetch a URL and return its body as text. Useful for docs and references."
    (list (cons "url" (prop "string" "HTTP or HTTPS URL."))
          (cons "format" (prop "string" "text or html. Default text.")))
    '("url"))
   (fn-schema
    "todowrite"
    "Replace the task list. Use for multi-step work."
    (list (cons "todos"
                (prop "array"
                      "Array of objects with content, status (pending|in_progress|completed|cancelled), and priority (high|medium|low).")))
    '("todos"))
   (fn-schema
    "todoread"
    "Read the current task list."
    '()
    '())))

(define current-todos (vector))

(define (reset-tools!)
  (set! current-todos (vector)))

(define (resolve workdir path)
  (cond
    ((or (not path) (string-null? path)) workdir)
    ((string-prefix? "/" path) path)
    (else (string-append (strip-trailing-slash workdir) "/" path))))

(define (status-code s)
  (or (status:exit-val s) 1))

(define (capture-lines cmd max-lines)
  (let* ((p (open-input-pipe cmd))
         (lines '())
         (n 0)
         (more #f))
    (let loop ()
      (let ((line (read-line p)))
        (if (eof-object? line)
            (let ((st (close-pipe p)))
              (values (string-join (reverse lines) "\n")
                      (status-code st)
                      more))
            (begin
              (if (< n max-lines)
                  (begin
                    (set! lines (cons line lines))
                    (set! n (+ n 1)))
                  (set! more #t))
              (loop)))))))

(define (run-bash workdir command timeout)
  (let* ((seconds (if (number? timeout) timeout 120))
         (cmd (string-append "cd " (shell-quote workdir)
                             " && timeout " (number->string seconds)
                             "s bash -lc " (shell-quote command)
                             " 2>&1")))
    (let-values (((text status more) (capture-lines cmd 400)))
      (string-append
       (if (> (string-length text) 60000)
           (substring text 0 60000)
           text)
       (if (or more (> (string-length text) 60000))
           "\n[output truncated]"
           "")
       "\n[exit " (number->string status) "]"))))

(define (read-file-safe workdir path offset limit)
  (let* ((full (resolve workdir path)))
    (if (not (file-exists? full))
        (string-append "error: no such file: " (or path "?"))
        (let* ((s (read-file* full))
               (lines (string-split s #\newline))
               (start (max 0 (- (or (and (number? offset) offset) 1) 1)))
               (count (or (and (number? limit) limit) (length lines)))
               (rest (drop lines start))
               (slice (take rest (min (length rest) (max 0 count)))))
          (string-join
           (map (lambda (l i)
                  (string-append (number->string i) "\t" l))
                slice
                (iota (length slice) (+ start 1)))
           "\n")))))

(define (write-file-safe workdir path content)
  (let ((full (resolve workdir path)))
    (write-file* full content)
    (string-append "wrote " (number->string (string-length content))
                   " chars to " full)))

(define (count-occurrences s needle)
  (let loop ((i 0) (n 0))
    (let ((j (string-contains s needle i)))
      (if j
          (loop (+ j 1) (+ n 1))
          n))))

(define (edit-file-safe workdir path old new)
  (let ((full (resolve workdir path)))
    (cond
      ((string-null? old) "error: old_string is empty")
      ((not (file-exists? full)) (string-append "error: no such file: " path))
      (else
       (let* ((s (read-file* full))
              (n (count-occurrences s old)))
         (cond
           ((zero? n) "error: old_string not found")
           ((> n 1) (string-append "error: old_string occurs " (number->string n)
                                   " times; make it unique"))
           (else
            (let ((i (string-contains s old)))
              (write-file* full
                           (string-append (substring s 0 i)
                                          new
                                          (substring s (+ i (string-length old)))))
              (string-append "edited " full)))))))))

(define (list-dir-safe workdir path)
  (let* ((full (resolve workdir (or path "."))))
    (if (not (file-exists? full))
        (string-append "error: no such directory: " (or path "?"))
        (let ((d (opendir full))
              (names '()))
          (let loop ()
            (let ((n (readdir d)))
              (unless (eof-object? n)
                (unless (member n '("." ".."))
                  (set! names (cons n names)))
                (loop))))
          (closedir d)
          (string-join
           (map (lambda (n)
                  (let ((f (string-append full "/" n)))
                    (if (and (file-exists? f)
                             (eq? (stat:type (stat f)) 'directory))
                        (string-append n "/")
                        n)))
                (sort names string<?))
           "\n")))))

(define (run-grep workdir pattern path include limit)
  (let* ((target (if (or (not path) (string-null? path)) "." path))
         (max-lines (if (number? limit) limit 200))
         (cmd (string-append
               "cd " (shell-quote workdir)
               " && grep -rn --color=never --exclude-dir=.git --exclude-dir=node_modules"
               (if (and (string? include) (not (string-null? include)))
                   (string-append " --include=" (shell-quote include))
                   "")
               " -e " (shell-quote (or pattern ""))
               " -- " (shell-quote target)
               " 2>&1")))
    (let-values (((out status more) (capture-lines cmd max-lines)))
      (cond
        ((string-null? out)
         (if (= status 1) "no matches" "no output"))
        (else
         (string-append out
                        (if more "\n[more matches truncated]" "")))))))

(define (run-glob workdir pattern path)
  (let* ((base (if (or (not path) (string-null? path)) "." path))
         (cmd (string-append
               "cd " (shell-quote workdir)
               " && cd " (shell-quote base)
               " && shopt -s globstar nullglob"
               " && compgen -G " (shell-quote (or pattern ""))))
         (max-lines 500))
    (let-values (((out status more) (capture-lines cmd max-lines)))
      (if (string-null? out)
          "no matches"
          (string-append out (if more "\n[more files truncated]" ""))))))

(define (run-patch workdir patch-text)
  (let ((tmp (string-append "/tmp/kerf-patch-"
                            (number->string (getpid))
                            "-"
                            (number->string (random 1000000))
                            ".diff")))
    (write-file* tmp patch-text)
    (dynamic-wind
      (lambda () #f)
      (lambda ()
        (let ((cmd (string-append "cd " (shell-quote workdir)
                                  " && patch -p0 --forward --batch -i "
                                  (shell-quote tmp) " 2>&1")))
          (let-values (((out status more) (capture-lines cmd 400)))
            (string-append out
                           (if (zero? status)
                               "\n[patch applied]"
                               (string-append "\n[patch exit "
                                              (number->string status) "]"))))))
      (lambda ()
        (when (file-exists? tmp)
          (delete-file tmp))))))

(define (webfetch-url url format)
  (if (not (or (string-prefix? "http://" url)
               (string-prefix? "https://" url)))
      "error: url must start with http:// or https://"
      (let* ((cmd (string-append "curl -sS -L -m 25 -A "
                                 (shell-quote "kerf/0.2")
                                 " " (shell-quote url) " 2>/dev/null"))
             (p (open-input-pipe cmd))
             (body (get-string-all p)))
        (close-pipe p)
        (if (string-null? body)
            "error: fetch failed or empty response"
            (let ((out (if (> (string-length body) 120000)
                           (substring body 0 120000)
                           body)))
              (string-append
               (if (string=? format "html") "[html]\n" "")
               out
               (if (> (string-length body) 120000)
                   "\n[truncated]"
                   "")))))))

(define (todo-status-mark s)
  (cond
    ((string=? s "completed") "[x]")
    ((string=? s "in_progress") "[~]")
    ((string=? s "cancelled") "[-]")
    (else "[ ]")))

(define (format-todos)
  (if (zero? (vector-length current-todos))
      "(no todos)"
      (string-join
       (map (lambda (t)
              (let ((content (or (json-get t "content") ""))
                    (status (or (json-get t "status") "pending"))
                    (priority (json-get t "priority")))
                (string-append
                 (todo-status-mark status)
                 " " content
                 (if (and (string? priority)
                          (not (string-null? priority))
                          (not (string=? priority "medium")))
                     (string-append " (" priority ")")
                     ""))))
            (vector->list current-todos))
       "\n")))

(define (todo-write todos)
  (set! current-todos
        (cond
          ((vector? todos) todos)
          ((list? todos) (list->vector todos))
          (else (vector))))
  (string-append (format-todos)
                 "\n\n"
                 (number->string (vector-length current-todos))
                 " todos"))

(define (maybe-confirm confirm desc)
  (if (procedure? confirm) (confirm desc) #t))

(define (execute-tool cfg call confirm)
  (let* ((fn (json-get call "function"))
         (name (json-get fn "name"))
         (args (catch #t
                 (lambda () (json-read-string (or (json-get fn "arguments") "{}")))
                 (lambda _ '())))
         (workdir (config-ref cfg "workdir")))
    (cond
      ((string=? name "bash")
       (let* ((command (or (json-get args "command") ""))
              (timeout (json-get args "timeout"))
              (desc (string-append "run: " (truncate-str command 160))))
         (if (maybe-confirm confirm desc)
             (cons name (run-bash workdir command timeout))
             (cons name "denied by user"))))
      ((or (string=? name "read") (string=? name "read_file"))
       (cons name (read-file-safe workdir
                                  (json-get args "path")
                                  (json-get args "offset")
                                  (json-get args "limit"))))
      ((or (string=? name "write") (string=? name "write_file"))
       (let* ((path (json-get args "path"))
              (content (or (json-get args "content") ""))
              (desc (string-append "write " path " ("
                                   (number->string (string-length content))
                                   " chars)")))
         (if (maybe-confirm confirm desc)
             (cons name (write-file-safe workdir path content))
             (cons name "denied by user"))))
      ((or (string=? name "edit") (string=? name "edit_file"))
       (let* ((path (json-get args "path"))
              (old (or (json-get args "old_string") ""))
              (new (or (json-get args "new_string") ""))
              (desc (string-append "edit " path)))
         (if (maybe-confirm confirm desc)
             (cons name (edit-file-safe workdir path old new))
             (cons name "denied by user"))))
      ((or (string=? name "list") (string=? name "list_dir"))
       (cons name (list-dir-safe workdir (json-get args "path"))))
      ((string=? name "grep")
       (cons name (run-grep workdir
                            (json-get args "pattern")
                            (json-get args "path")
                            (json-get args "include")
                            (json-get args "limit"))))
      ((string=? name "glob")
       (cons name (run-glob workdir
                            (json-get args "pattern")
                            (json-get args "path"))))
      ((string=? name "patch")
       (let ((text (or (json-get args "patch") "")))
         (if (string-null? text)
             (cons name "error: patch is empty")
             (if (maybe-confirm confirm "apply patch")
                 (cons name (run-patch workdir text))
                 (cons name "denied by user")))))
      ((string=? name "webfetch")
       (cons name (webfetch-url (or (json-get args "url") "")
                                (or (json-get args "format") "text"))))
      ((string=? name "todowrite")
       (cons name (todo-write (json-get args "todos"))))
      ((string=? name "todoread")
       (cons name (format-todos)))
      (else
       (cons (or name "unknown")
             (string-append "error: unknown tool " (or name "?")))))))
