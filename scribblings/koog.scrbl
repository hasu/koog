#lang scribble/manual
@(require scribble/basic scribble/core "util.rkt")
@(require (for-label racket/cmdline koog/koog koog/runtime))

@(require setup/getinfo)
@(define info (get-info (list "koog")))

@title{Koog}

@author["Tero Hasu"]

@section[#:tag "concept"]{Concept}

@emph{Mixed-code generation} is a form of template-based code generation where the template file is overwritten with the generated file, with the code generation directives intact. The term was (as far as we know) introduced by Jack Herrington in his book Code Generation in Action (Manning, 2003).

Koog can function as a traditional mixed-code generator for a host language that uses one of the supported code styles (currently C and Racket block comments, or Lisp, Ruby, or TeX line comments). Koog also supports a restricted form of mixed-code generation where only specific regions of the source file are actually regenerated.

@section[#:tag "terminology"]{Terminology}

@(begin
(define definition-style (style 'definition (list (background-color-property (list #xfa #xfa #xfa)))))
(define-syntax-rule (definition pre-content ...) (para #:style definition-style (bold "Definition.") " " pre-content ...)))

@definition{A @defterm{mixed-code generator} is a compiler that modifies its input based on instructions found in the input itself, and produces output which can be (repeatedly) re-fed to the compiler as valid input.}

@definition{The instructions, which are given in a (generator-dictated) @defterm{generator language}, are retained in the output.}

@definition{The input may also include some (potentially foreign) @defterm{host language} text, and the goal typically is for the entire generator output to be a valid host language document.}

@definition{Specially formatted host language comments in the input function both as: @defterm{directive}s specifying what text to generate; and as @defterm{marker}s identifying the @defterm{region}s of host language text that are allowed to be replaced.}

@definition{A region and its enclosing markers together constitute a @defterm{section}.}

@section[#:tag "features"]{Features}

@; Single-collection packages are supported since Racket 6.0.

@(itemlist
  @item{Supports Racket version 6.}
  @item{Includes a Racket API, command-line interface, and Emacs/Vim editor integration.}
  (item "It is possible to:"
  (itemlist
    @item{Expand all regions in a file, or only expand a chosen region (specified by line number).}
    @item{Remove code generation directives (for one-off operations).}
    @item{Simulate an expansion (see what would be changed without changes to the input file).}
    @item{Filter standard input (and print the result to standard output).}
   ))
  )

@section[#:tag "api"]{API}

The provided APIs are fairly self-explanatory, so look at the source code for the details of the provided functionality.

@subsection{Code Generator}

@defmodule[koog/koog]

The primary module of Koog is @racketmodname[koog/koog], which exports the @racket[koog-expand] function (for expanding file regions with generated code), and some parameters affecting its behavior.

@defproc[(koog-expand [input (or/c input-port? #f)]
         	      [output (or/c output-port #f)]
		      [filename path-string?])
         boolean?]{
Expands input regions as specified by directives, and produces resulting output. Non-regions are generally copied as is, but the exact behavior of the expansion process may be modified through the relevant @racketmodname[koog/koog] parameters (e.g., @racketid[only-on-line] and @racketid[remove-markers?]).
The @racket[input] port may be @racket[#f], in which case input is read from the file named by @racket[filename]. The @racket[output] port may likewise be @racket[#f], in which case the output is written to the file @racket[filename]. If both @racket[input] and @racket[output] ports are given, @racket[filename] is only used for informational purposes.
The function returns @racket[#f] if the generated output differs from the read input, and @racket[#t] otherwise.}

@subsection{Code-Generation Context Information}

@defmodule[koog/runtime]

The @racketmodname[koog/runtime] module exports parameters that make context information available to code generation directives. It is not necessary to explicitly @racket[require] this module, as its variables get set and bound for directives automatically by Koog.

@subsection{Command-Line Program Module}

@defmodule[koog/cli]

The @racketmodname[koog/cli] module has no exports. It just contains code for parsing command-line options and accordingly setting parameters for @racket[koog-expand] prior to invoking it.

@section{CLI}

The command-line interface is provided by the @tt{koog} program, and it has various options whose combinations can cater for a number of use cases.

For example, to modify the file @filepath{cli.rkt} in place, expanding its regions, we can
@commandline{koog -c racket cli.rkt}

To merely check what would be done, we can simulate the expansion with
@commandline{koog -c racket -s cli.rkt}
which shows any changes that would be made, or any error in the input.

To only expand within markers enclosing line 42:
@commandline{koog -c racket -l 42 cli.rkt}

To pipe input through the program to get it expanded, we can
@commandline{cat cli.rkt | koog -c racket -io -f cli.rkt}
where the @tt{-f cli.rkt} option is only present for possible informational use.

To see how @filepath{cli.rkt} would look with any markers at line 42 removed, we can issue
@commandline{koog -c racket -l 42 -ro cli.rkt | less}

@section[#:tag "examples"]{Examples}

Here are some real-world Koog-based code generation examples from the @hyperlink["http://contextlogger.github.io/"]{ContextLogger2} codebase:

@itemlist[
 @item{@hyperlink["http://contextlogger.github.io/api/epoc-indicator_8hpp_source.html"]{generating code for Symbian two-phase construction};}
  @item{@hyperlink["http://contextlogger.github.io/api/lua__bindings_8cpp_source.html"]{generating boilerplate code for Lua bindings};}
  @item{@hyperlink["http://contextlogger.github.io/api/cf__rcfile_8cpp_source.html"]{fetching a multi-line string from a file and declaring it as a CPP (preprocessor) definition}.}

]

We can also find a Koog use example from within Koog itself.
A @racketvarfont{help-spec} for the @racket[command-line] macro must be a literal string (or a list thereof), but in Koog's @filepath{cli.rkt} we wanted to use a contant expression to build that string. One way to do that is with Koog:
@verbatim{
#|***koog  
(require racket/list koog/koog)
(write (format "~a (default: ~a)" 
               (apply string-append 
                      (add-between 
                       (map symbol->string (comment-style-names)) 
                       ", ")) 
               (default-comment-style-name)))
***|# "c, lisp, racket, sh, tex (default: c)" #|***end***|}
This solution in effect creates yet another phase of code expansion, happening already before macroexpansion, but only when we choose to trigger it. (An example of a macro-based solution would be to macro-generate our @racket[command-line] use, inserting the computed @racketvarfont{help-spec} string within it).

@section{Installation}

The pre-requisites for installing the software are:
@itemlist[

  @item{@bold{Racket.} Version 6.0 (or higher) of Racket is required; a known-compatible version is 6.10.1.}

]

The software and the documentation can be built from source, or installed directly using the Racket package manager. With Racket and its tools available, Koog can be installed with the @exec{raco} command:
@commandline{raco pkg install @pkg-install-git-url["hasu" "koog"]}

The above commands should install the library, the @tt{koog} command-line program, and a HTML version of the manual.

To check that the library has been installed, you can use the command
@commandline{racket --eval '(require koog/koog)'}

To check that the command-line program has been installed and is on your executable search @tt{PATH}, you might query for program usage information with
@commandline{koog --help}

To check that the Koog manual has been incorporated into your local copy of the Racket documentation, try searching for ``koog'' with
@commandline{raco docs koog}

@subsection{Editor Integration}

For information about configuring Emacs and Vim to use Koog, see the readme files in the @filepath{emacs} and @filepath{vim} directories of the source distribution.

@section{Source Code}

The Koog source code @hyperlink["http://git-scm.com/"]{Git} repository is hosted at:
@nested[#:style 'inset @url{https://github.com/hasu/koog}]

@section[#:tag "faq"]{Hardly Ever Asked Questions (HEAQ)}

@bold{Q:} Where does the name "Koog" come from?@linebreak{}
@bold{A:} It is short for the Finnish word "@emph{koo}di@emph{g}eneraattori" (code generator).

@section[#:tag "license"]{License}

Except where otherwise noted, the following license applies:

@(include-at-exps "../LICENSE")
