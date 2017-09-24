(this README is being written; enjoy the help output in the meantime)

```
usage: ./macgetalbums [-achlmv] [-u collector]
  -a - show tracks that have missing or duplicate artwork (overrides -c)
  -c - show track and album count and total playing time and quit
  -h - show this help
  -l - show album lengths
  -m - show times in minutes instead of hours and minutes
  -u - use the specified collector
  -v - print verbose output
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
