#!/bin/sh
#SRCDIR=$(dirname $(readlink -f $0))
#CLIRKT=$SRCDIR/cli.rkt
exec racket --name "$0" --eval '(require koog/cli) (main)' -- ${1+"$@"}
#exec racket --require-script "$CLIRKT" --main -- ${1+"$@"}
