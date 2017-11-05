#lang racket/base

#|
|#

(require "../util.rkt"
         (for-syntax racket/base racket/port
                     syntax/parse
                     (prefix-in at. scribble/reader)))

(define* (pkg-install-git-url user pkg [rev #f])
  (if rev
      (format "git://github.com/~a/~a#~a" user pkg rev)
      (format "git://github.com/~a/~a" user pkg)))

;;; 
;;; string inlining
;;;

;; The argument `file-stx` is a literal file name string. Turn it into
;; a complete file path, and return the result. Interpret relative
;; paths as relative to the syntax location of `file-stx`.
(define-for-syntax (literal-path->complete-path file-stx)
  (define form-src (syntax-source file-stx))
  (define form-dir (let-values (((d x y) (split-path form-src))) d))
  (define source-file
    (path->complete-path (syntax-e file-stx) form-dir))
  source-file)

(define-syntax* (include-string stx)
  (syntax-parse stx
    [(_ file:str)
     (define source-file (literal-path->complete-path #'file))
     (define s (call-with-input-file source-file port->string))
     (datum->syntax stx s
                    (list (path->string source-file)
                          1 0 1 (string-length s)))]))

;; Read a textual file `f`, which may contain @-expressions. Return a
;; syntactic list containing the read @-expressions.
(define-for-syntax (read-at-inside-from-file f)
  (call-with-input-file f
    (lambda (in)
      (at.read-syntax-inside
       (path->string (path->complete-path f))
       in))))

;; Inline the contents of a `file` at the macro invocation site,
;; reading the file in as if the contents appeared within an @{...}
;; form. Quete the inserted content so that it does not get evaluated,
;; but rather gets treated as constant Scribble pre-content. This
;; differs from `include-string` as multiple tokens may be read, and
;; the end result can thus be multiple different document elements.
(define-syntax* (include-at-exps stx)
  (syntax-parse stx
    [(_ file:str)
     (define source-file (literal-path->complete-path #'file))
     (quasisyntax/loc stx
       (quote (unsyntax (read-at-inside-from-file source-file))))]))
