(define-module (agent)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-13)
  #:use-module (json)
  #:use-module (config)
  #:use-module (util)
  #:use-module (tools)
  #:use-module (http)
  #:export (system-message run-agent *reasoning-hook*))

(define *reasoning-hook* #f)

(define (system-message cfg)
  `(("role" . "system")
    ("content" .
     ,(string-append
       "You are kerf, a terse coding agent in a terminal. "
       "Working directory: " (config-ref cfg "workdir") ".\n"
       "Use tools for every file inspection and change. Never invent file contents. "
       "Read before editing. Prefer small exact edits. "
       "Tools: bash, read, write, edit, list, grep, glob, patch, webfetch, todowrite, todoread.\n"
       "If native tool calls are unavailable, emit each call in exactly this format, with no prose around it:\n"
       "<tool_call>\n"
       "{\"name\":\"read\",\"arguments\":{\"path\":\"src/main.scm\"}}\n"
       "</tool_call>\n"
       "You may emit several <tool_call> blocks in one reply. Stop after the calls and wait for results. "
       "Keep prose short. Act instead of describing the action. "
       "Do not wrap tool calls in markdown fences."))))

(define (assistant-message content toolcalls)
  (append
   `(("role" . "assistant")
     ("content" . ,(if (string-null? content) 'null content)))
   (if toolcalls
       `(("tool_calls" . ,toolcalls))
       '())))

(define (tool-message id content)
  `(("role" . "tool")
    ("tool_call_id" . ,id)
    ("content" . ,content)))

(define (run-agent cfg messages on-text on-tool confirm on-replace)
  (let loop ((msgs messages)
             (step 0))
    (if (>= step (config-ref cfg "max_steps"))
        (begin
          (on-tool "limit" (string-append "stopped after "
                                          (number->string step)
                                          " steps"))
          msgs)
        (let-values (((content toolcalls finish reasoning)
                      (stream-chat cfg msgs (tool-definitions) on-text #f)))
          (when on-replace
            (on-replace content))
          (when (and (string? reasoning) (not (string-null? reasoning)))
            (when *reasoning-hook*
              (*reasoning-hook* reasoning)))
          (let* ((assistant (assistant-message content toolcalls))
                 (next (append msgs (list assistant))))
            (if (or (not toolcalls) (zero? (vector-length toolcalls)))
                next
                (let* ((results
                        (map (lambda (call)
                               (let* ((fn (json-get call "function"))
                                      (name (json-get fn "name"))
                                      (id (json-get call "id")))
                                 (on-tool name (string-append "using " name))
                                 (let ((result (execute-tool cfg call confirm)))
                                   (on-tool name (cdr result))
                                   (tool-message id (cdr result)))))
                             (vector->list toolcalls))))
                  (loop (append next results) (+ step 1)))))))))