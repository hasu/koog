#!/bin/sh
exec racket --name "$0" --eval '(require koog/cli) (main)' -- ${1+"$@"}
