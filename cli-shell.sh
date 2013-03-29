#!/bin/sh
SRCDIR=$(dirname $(readlink -f $0))
CLIRKT=$SRCDIR/cli.rkt

exec racket --name "$0" --require "$CLIRKT" --main -- ${1+"$@"}

#exec racket --name "$0" --eval '(require koog/cli) (main)' -- ${1+"$@"}

# actually seems not to be the same as -t <file> -N <file>
#exec racket --require-script "$CLIRKT" --main -- ${1+"$@"}
