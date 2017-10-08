(this README is being written; enjoy the help output in the meantime)

```
usage: ./macgetalbums [options]
  -a	show tracks that have missing or duplicate artwork (overrides -c and -p)
  -c	show track and album count and total playing time and quit
  -help/-h
    	show this help and quit
  -l	show album lengths
  -m	show times in minutes instead of hours and minutes
  -o string
    	sort by the given key (artist, year, length, none; default is year)
  -p	write a PDF gallery of albums to stdout (overrides -c)
  -r	reverse sort order
  -u string
    	use the specified collector
  -v	print verbose output
  -xb string
    	if specified, exclude albums whose names match the given regexp
known collectors; without -u, each is tried in this order:
 iTunesLibraryCollector
  iTunesLibrary.framework (provides fast read-only access to iTunes; requires iTunes v11.0 or newer and code signing)
 ScriptingBridgeCollector
  Scripting Bridge (uses AppleScript to talk to iTunes; will launch iTunes as a result)
```

TODOs:
- write this README
- fine-tune system requirements
- see if we can dynamically load Security.framework
- get the more shell-independent codesign makefile check from my IRC logs
- run with `OBJC_DEBUG_MISSING_POOLS=YES` and other `OBJC_HELP=YES` options
