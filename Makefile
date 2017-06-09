# -Wno-four-char-constants is to deal with sdp output :| (TODO see if there's a workaround)
all: macgetalbums.m iTunes.h
	clang -o macgetalbums macgetalbums.m -framework Foundation -framework ScriptingBridge -g -Wall -Wextra -pedantic -Wno-unused-parameter --std=c99 -Wno-four-char-constants

iTunes.h:
	sdef /Applications/iTunes.app | sdp -fh --basename iTunes
