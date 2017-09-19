# 8 june 2017

OUT = macgetalbums

MFILES = \
	amisigned.m \
	duration.m \
	item.m \
	ituneslibrary.m \
	main.m \
	scriptingbridge.m \
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
	-framework CoreFoundation \
	-framework Foundation \
	-framework ScriptingBridge \
	-framework Security

$(OUT): $(OFILES)
	clang -o $@ $(OFILES) $(LDFLAGS)

%.o: %.m $(HFILES)
	clang -c -o $@ $< $(MFLAGS)

iTunes.h:
	sdef /Applications/iTunes.app | sdp -fh --basename iTunes

clean:
	rm -f $(OFILES) $(OUT) iTunes.h
.PHONY: clean
