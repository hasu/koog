VIM INTEGRATION SETUP

To set up Koog for use within the Vim editor, you might add something
like the following to your ~/.vimrc file:

  if filereadable("/path/to/koog/vim/koog.vimrc")
    source /path/to/koog/vim/koog.vimrc
  endif

Having done this, you should be able to insert Koog markers with the
command m i, and so forth. See the koog.vimrc file for more
information.
