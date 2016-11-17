#!/bin/sh

PREFIX=.

# leave the .git and .stack-work folder and temporary files

find $PREFIX \
  -regextype posix-extended \
  -type f \
  -a ! \( -regex "^${PREFIX}/\.git/.*" -o -regex "^${PREFIX}/\.stack-work/.*"  -o -regex "^${PREFIX}/\.liquid/.*" \) \
  -a ! -regex '.*\.(o|s|dSYM|run|log|result)$'
