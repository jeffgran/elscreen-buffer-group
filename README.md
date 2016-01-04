# Summary

This is a rewrite/overhaul of an existing package called elscreen-buffer-list,
fixed for emacs 24 and the latest version of elscreen from MEL PA.

Enabling this package gives each elscreen its own buffer group.
When a buffer is first displayed, it automatically gets added to the
group of the current elscreen. Then, while you're in that elscreen,
you'll only be able to see those buffers that belong to that elscreen.

This works by hijacking some low-level buffer access functions, which
are the only functions (that I can find) that generate the master
list of buffers, at the lowest level. If you find a place where this
doesn't look, report it and I'm sure we can find a function to advise.

In order to give you an "out" to see ALL the buffers in case you want to,
you can add a command name (a symbol) to 'elscreen-bg-skip-commands and
elscreen-bg will "skip" the filtering advice on that command. By default
this is set to just 'ibuffer, but you can make it whatever you want. All
other commands will use the filtered list.

# Usage

You have to be using elscreen, then just require it.

```lisp
(require 'elscreen)
(require 'elscreen-buffer-group)
```

You can choose which commands do NOT filter the buffer list:

```lisp
(setq 'elscreen-buffer-group-skip-commands `(my-special-buffer-switching-command))
```

You can turn on/off exclusivity, meaning a buffer can ONLY belong to one
screen at a time. If this is nil, a buffer can be in more than one screen.
If it's non-nil, adding a buffer to a screen (displaying it while in that
screen) will remove it from all other screens:

```lisp
(setq elscreen-buffer-group-exclusive nil)
```
