#lang racket/base

#|

This file implements the command-line interface of Koog.

|#

(require racket/cmdline
         racket/list
         racket/port
         "koog.rkt"
         "util.rkt")

#|***koog  
(require racket/list koog/koog)
(define style-help-spec
  (format "~a (default: ~a)" 
          (apply string-append 
                 (add-between 
                  (map symbol->string (comment-style-names)) 
                  ", ")) 
          (default-comment-style-name)))
***|#  #|***end***|#

(module* main #f
  (let ()
    ;; (writeln (find-system-path 'exec-file)) ;; interpreter name
    ;; (writeln (find-system-path 'run-file)) ;; program name
    ;; (writeln (current-command-line-arguments)) ;; args

    (define from-stdin (make-parameter #f)) ;; #f ==> from file
    (define out-stream (make-parameter #f)) ;; #f ==> to file
    (define files #f)
    (define stdin-filename (make-parameter #f)) ;; #f means none or unknown
    
    (command-line
     #:program (find-system-path 'run-file) ;; program name
     #:argv (current-command-line-arguments)
     #:once-each
     (("-c" "--style") style
      #|***koog (write style-help-spec) ***|#
"c, lisp, racket, sh, tex (default: c)" #|***end***|#
      (comment-style (string->symbol style)))
     (("-d" "--diff")     "print a diff to STDOUT"
      (diff-stream (current-output-port)))
     (("-f" "--filename") filename  "filename for when from STDIN"
      (stdin-filename filename))
     (("-i" "--stdin")    "read input from STDIN (when no files specified)"
      (from-stdin #t))
     (("-n" "--null")     "print expanded input to /dev/null only"
      (out-stream (open-output-nowhere)))
     (("-o" "--stdout")   "print expanded input to STDOUT only"
      (out-stream (current-output-port)))
     (("-l" "--line") integer  "expand section containing line only"
      (only-on-line (string->number integer)))
     (("-q" "--quiet")    "be quiet"
      (be-quiet? #t))
     (("-r" "--remove")   "remove markers"
      (remove-markers? #t))
     (("-s" "--simulate") "short for -dnq"
      (begin
        (be-quiet? #t)
        (diff-stream (current-output-port))
        (out-stream (open-output-nowhere))))
     #:args file (set! files file))
  
    ;;(writeln (list files (only-on-line)))

    (if (from-stdin)
        (koog-expand (current-input-port)
                     (or (out-stream) (current-output-port))
                     (stdin-filename))
        (for-each
         (lambda (filename)
           (koog-expand #f (out-stream) filename))
         files))

    (void)))
