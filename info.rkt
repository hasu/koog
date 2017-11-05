#lang info
(define name "Koog")
(define blurb '("A mixed-code generator library and command-line tool."))
(define scribblings '(("scribblings/koog.scrbl" ())))
(define racket-launcher-libraries '("cli.rkt"))
(define racket-launcher-names '("koog"))
(define compile-omit-paths '("dist" "emacs" "notes" "retired" "tools" "vim" "web"))
(define deps '(("base" #:version "6.3")))
(define build-deps '("at-exp-lib" "racket-doc" "scribble-lib"))
