#lang racket/base

#|

This file implements the API of Koog, a code generator in the style
of Cog. The primary difference is that the code generation
definitions are given in Racket. Also, it is possible to
(re)generate just a particular region of code rather than all the
regions in a file, while still evaluating all of the Racket code in
the file.

The cogapp.py and whiteutils.py source files of Cog are a useful
reference when implementing tools such as this.

This module requires PLT Scheme / Racket version 5 or higher.

|#

(require racket/function
         racket/list
         racket/port
         "runtime.rkt"
         "util.rkt")

(stdout (current-output-port))
(stderr (current-error-port))

;; Prints no status messages.
(define* be-quiet? (make-parameter #f))

;; Prints the changes made to the input, for each modified section.
;; Must specify an output stream.
(define* diff-stream (make-parameter #f))

;; Causes only the section containing the specified line to be
;; modified. Sections fully or partially contained within the specified
;; line are included.
;; 
;; Line must be an integer line number, counting from 1. Under Emacs,
;; see our own "get-current-line" function, unless there is a built-in
;; function for getting the line number. We deal with line numbers
;; rather than character or byte positions to avoid possibly
;; inconsistencies caused by different line break and character
;; encodings.
(define* only-on-line (make-parameter #f))

;; Causes markers and directives to be removed, retaining only the
;; region. This may be useful for wizard-type one-off code generation.
(define* remove-markers? (make-parameter #f))

(define (capture-output f)
  (let ((output (open-output-string)))
    (parameterize ((current-output-port output))
      (f))
    (get-output-string output)))

(define (discard-output f)
  (let ((output (open-output-nowhere)))
    (parameterize ((current-output-port output))
      (f))))

;; old-section:: The original text for the entire section. Almost
;;               never required, I suppose, but we do not try to guess
;;               what the user might want to do.
;; directive:: The directive to evaluate.
;; old-region:: Typically not required, but might be fun to write
;;              a directive that is a function of the old code.
;; namespace:: The namespace in which to evaluate the code.
;; filename:: The input filename, or #f for none.
(define (evaluate-section old-section directive old-region namespace filename)
  ;;(writeln (list "DIRECTIVE" directive))
  (let ((input (open-input-string directive)))
    (parameterize ((rt.filename (and filename (string->path filename)))
                   (rt.section old-section)
                   (rt.directive directive)
                   (rt.region old-region))
      (let loop ()
        (let ((datum (read input)))
          (unless (eq? datum eof)
            (with-handlers (((lambda (v) #t)
                             (lambda (v)
                               (display (format "<<error: ~a>>" v))
                               (newline))))
              (eval datum namespace))
            (loop)))))))

;; We support the C comment style
;;
;;   /***koog DIRECTIVE ***/ REGION /***end***/
;;
;; and the Lisp comment style
;;
;;   ;***koog DIRECTIVE ;***
;;   REGION ;***end
;;
;; or
;;
;;   ;***koog
;;   ;
;;   ; DIRECTIVE
;;   ;
;;   ;***
;;   REGION
;;   ;***end
;;
;; and similarly for Perl and TeX.
;;
;; Only the REGION part is modified by the compiler.

(define (mk-line-cmt-re pat)
  (byte-pregexp
   (bytes-append
    #"^(.*?)(" pat
    #"[*]{3,}koog)(.*?)(" pat
    #"[*]{3,}[[:blank:]\r]*\n)(.*?)(" pat
    #"[*]{3,}end)")))

(define (mk-block-cmt-re o-pat c-pat (mid-o-pat #f) (mid-c-pat #f))
  (byte-pregexp
   (bytes-append
    #"^(.*?)(" o-pat
    #"[*]{3,}koog)(.*?)([*]{3,}" (or mid-c-pat c-pat)
    #")(.*?)(" (or mid-o-pat o-pat)
    #"[*]{3,}end[*]{3,}" c-pat #")")))

(define (mk-line-cmt-filt pat)
  (let ((re (byte-pregexp
             (bytes-append
              #"[[:blank:]\r]*\n[[:blank:]]*" pat))))
    (lambda (x)
      (regexp-replace* re x " "))))

(define (mk-line-cmt-style name pat)
  (list name (mk-line-cmt-re pat) (mk-line-cmt-filt pat)))

(define (mk-block-cmt-style name . pats)
  (list name (apply mk-block-cmt-re pats) identity))

;; We use a byte regexp to get better performance when matching against a port.
(define style-list
  `(,(mk-block-cmt-style 'c #"/" #"/")
    ,(mk-line-cmt-style 'lisp #";+")
    ,(mk-block-cmt-style 'racket #"#[|]" #"[|]#"
                         #"[[:space:]]#[|]" #"[|]#[[:space:]]")
    ,(mk-line-cmt-style 'sh #"#+")
    ,(mk-line-cmt-style 'tex #"%+")))

;#px#"^(.*?)(#[|][*]{3,}koog)(.*?)([*]{3,}[|]#)(.*?)(#[|][*]{3,}end[*]{3,}[|]#)"
;#px#"^(.*?)(/[*]{3,}koog)(.*?)([*]{3,}/)(.*?)(/[*]{3,}end[*]{3,}/)"
;#px#"^(.*?)(;+[*]{3,}koog)(.*?)(;+[*]{3,}[[:blank:]\r]*\n)(.*?)(;+[*]{3,}end)"
;(lambda (x) (regexp-replace* #px#"[[:blank:]\r]*\n[[:blank:]]*;+" x " "))
    
;;(regexp-match (second (assq 'c style-list)) "foo bar /***koog my directive ***/ my region /***end***/")
;;(regexp-match (second (assq 'lisp style-list)) "foo bar ;***koog my directive ;***\n my region ;***end")
;;(regexp-match (second (assq 'lisp style-list)) "foo bar ;***koog my directive\r\n ; directive continues ;***\r\n my region ;***end")

(define (validate-get-style s)
  (let ((p (assq s style-list)))
    (unless p
      (error 'validate-get-style
             "unsupported comment style: ~a not in ~a"
             s (map car style-list)))
    p))

(define* comment-style (make-parameter (first style-list)
                                       validate-get-style))

(define* (comment-style-names)
  (map first style-list))

(define* (default-comment-style-name)
  (first (first style-list)))

(define lf-byte (bytes-ref #"\n" 0))

(define (bytes-count-lf bstr)
  (for/fold ((count 0))
      ((b bstr))
    (if (equal? b lf-byte)
        (+ count 1)
        count)))

;; Relative module paths tend to be dynamically resolved relative to
;; (current-directory), so we resolve explicitly relative to this
;; module. We could just use 'koog/runtime instead, but that relies on
;; the collects path.
(define runtime-module-path
  ((current-module-name-resolver)
   '"runtime.rkt"
    (variable-reference->resolved-module-path
     (#%variable-reference))
    #f #f))

;; A raw path is something that cannot appear as syntax, but will be
;; accepted by #%require and namespace-require.
(define runtime-module-path-name
  (resolved-module-path-name runtime-module-path))

(define (modify-data-in-stream input output filename logstream)
  (define lineno 1)
  (define modified #f)

  ;; (make-base-empty-namespace) includes so little that even literal
  ;; use or function application is not defined. This gives us
  ;; racket/base.
  (define ns (make-base-namespace))

  (define style (comment-style))
  (define style-re (second style))
  (define dir-filt (third style))
  
  (begin
    (namespace-attach-module (current-namespace) runtime-module-path ns)
    (parameterize ((current-namespace ns))
      (namespace-require runtime-module-path-name)))
  
  (let loop ()
    ;; regexp-match does support matching agains input ports, which is
    ;; handy and efficient here, but input ports always yield bytes,
    ;; not strings, and hence the result will also be a byte string.
    ;; If there is a match, that is.
    ;; 
    ;; Note that any non-matches will automatically be fed to
    ;; "output", which does happen to be handy in this case.
    (let ((res (regexp-match style-re input 0 #f output)))
      ;;(pretty-nl (list "RE RES" res))
      (when res
          (let* ((pre-section (second res))
                 (section (apply bytes-append (cddr res)))
                 (pre-lf-count (bytes-count-lf pre-section))
                 (lf-count (bytes-count-lf section))
                 (start-line (+ lineno pre-lf-count))
                 (end-line (+ start-line lf-count)))
            (write-bytes pre-section output)

            (let* ((section-parts (cddr res))
                   (start-marker (first section-parts))
                   (directive (second section-parts))
                   (middle-marker (third section-parts))
                   (region (fourth section-parts))
                   (end-marker (fifth section-parts))
                   (directive-s (bytes->string/utf-8 (dir-filt directive)))
                   (region-s (bytes->string/utf-8 region))
                   (do-evaluate-section
                    (thunk
                     (evaluate-section section directive-s
                                       region-s ns filename)))
                   (not-line?
                    (let ((only (only-on-line)))
                      (and only (or (< only start-line)
                                    (> only end-line))))))
              (if not-line?
                  (begin
                    (discard-output do-evaluate-section)
                    (write-bytes section output))
                  (let* ((new-region-s
                          (capture-output do-evaluate-section))
                         (region-unchanged? (equal? region-s new-region-s))
                         (just-region? (remove-markers?)))
                    (if (and region-unchanged? (not just-region?))
                        (write-bytes section output)
                        (begin
                          (unless just-region?
                            (write-bytes start-marker output)
                            (write-bytes directive output)
                            (write-bytes middle-marker output))
                          (write-string new-region-s output)
                          (unless just-region?
                            (write-bytes end-marker output))
                          (when logstream
                            (let ((num
                                   (apply + start-line
                                          (map bytes-count-lf
                                               (list start-marker
                                                     directive
                                                     middle-marker))))
                                  (filename/log
                                   (or filename "<stdin>")))
                              (display
                               (format "~a:~a:«" filename/log num)
                               logstream))
                            (write-bytes region logstream)
                            (display "» --> «" logstream)
                            (write-string new-region-s logstream)
                            (display "»" logstream)
                            (when just-region?
                              (display " (markers removed)" logstream))
                            (newline logstream))
                          (set! modified #t)))))
              
              (set! lineno end-line)
              (loop))))))
    modified)

;; Returns #t iff the data was modified.
;; a-output:: May be #f, in which case the file is modified in place.
;;            For stdout, you may want to use (current-output-port).
(define (modify-data-in-file filename a-output logstream)
  (let* ((content (read-string-from-file filename))
         (input (open-input-string content))
         (output (or a-output (open-output-string)))
         (modified (modify-data-in-stream input output
                                          filename logstream)))
    (when (and modified (not a-output))
      (unless (be-quiet?) (displayln filename))
      (call-with-output-file
          filename
        (lambda (file-output)
          (write-string (get-output-string output) file-output))
        #:exists 'truncate/replace))
    modified))

;; Returns #t iff the output differs from the input.
;; input:: An input port. May be #f, in which case input is read from
;;         the file "filename".
;; output:: An output port. May be #f, in which case the output is
;;          written to the file "filename".
;; filename:: Input (and possibly output) filename. If both "input"
;;            and "output" ports are given, "filename" is only used
;;            for informational purposes.
(define* (koog-expand input output filename)
  (when (and input (not output))
    (error "cannot specify input without output port"))

  ;; We do wish to return the value of this expression.
  (if input
      (modify-data-in-stream input output
                             filename (diff-stream))
      (modify-data-in-file filename output (diff-stream))))
