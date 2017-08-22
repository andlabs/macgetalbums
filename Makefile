# 8 june 2017

OUT = macgetalbums

MFILES = \
	item.m \
	main.m \
	timer.m

HFILES = \
	macgetalbums.h \
	iTunes.h

OFILES = \
	$(MFILES:%.m=%.o)

# -Wno-four-char-constants is to deal with sdp output :| (TODO see if there's a workaround)
MFLAGS = \
	--std=c99 -g \
	-Wall -Wextra -pedantic \
	-Wno-unused-parameter -Wno-four-char-constants

LDFLAGS = \
	--std=c99 -g \
	-framework Foundation \
	-framework ScriptingBridge

$(OUT): $(OFILES)
	clang -o $@ $(OFILES) $(LDFLAGS)

%.o: %.m $(HFILES)
	clang -c -o $@ $< $(MFLAGS)

iTunes.h:
	sdef /Applications/iTunes.app | sdp -fh --basename iTunes

clean:
	rm -f $(OFILES) $(OUT) iTunes.h
.PHONY: clean
