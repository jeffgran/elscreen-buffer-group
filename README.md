This is a rewrite/overhaul of an existing package called elscreen-buffer-list,
fixed for emacs 24 and the latest version of elscreen from MEL PA.

Enabling this package gives each elscreen its own buffer group.
When a buffer is first displayed, it automatically gets added to the
group of the current elscreen. Then, while you're in that elscreen,
you'll only be able to see those buffers that belong to that elscreen.

This works by hijacking (buffer-list) and (ido-make-buffer-list), which
are the only two functions (that I can find) that generate the master
list of buffers, at the lowest level.

In order to give you an "out" to see ALL the buffers in case you want to,
you can add a command name (a symbol) to 'elscreen-bg-skip-commands and
elscreen-bg will "skip" the filtering advice on that command. By default
this is set to just 'ibuffer, but you can make it whatever you want. All
other commands will use the filtered list.
