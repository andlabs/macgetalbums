# 8 june 2017

OUT = macgetalbums

MFILES = \
	addmethod.m \
	album.m \
	collector.m \
	duration.m \
	errors.m \
	issigned.m \
	ituneslibrary.m \
	main.m \
	options.m \
	pdf.m \
	printlog.m \
	scriptingbridge.m \
	timer.m \
	track.m

HFILES = \
	macgetalbums.h \
	options.h \
	optpriv.h \
	iTunes.h

OFILES = \
	$(MFILES:%.m=%.o)

# -Wno-four-char-constants is to deal with sdp output :| (TODO see if there's a workaround)
MFLAGS = \
	--std=c99 -g \
	-Wall -Wextra -pedantic \
	-Wno-unused-parameter -Wno-four-char-constants

OPTMFLAGS = \
	-mmacosx-version-min=10.0

LDFLAGS = \
	--std=c99 -g \
	-framework CoreFoundation \
	-framework Foundation \
	-framework AppKit \
	-framework ScriptingBridge \
	-framework Security

# this defaults the signing type to ad-hoc, which is sufficient for our needs
CODESIGNFLAGS = \
	-s -

# thanks to geirha in irc.freenode.net #bash for the knowledge that the exit status of an if that doesn't run its then and has no else is 0
$(OUT): $(OFILES)
	clang -o $@ $(OFILES) $(LDFLAGS)
	if type codesign > /dev/null 2>&1; then codesign $(CODESIGNFLAGS) $@; fi

%.o: %.m $(HFILES)
	clang -c -o $@ $< $(MFLAGS)

addmethod.o: addmethod.m options.h optpriv.h
	clang -c -o $@ $< $(MFLAGS) $(OPTMFLAGS)

options.o: options.m options.h optpriv.h
	clang -c -o $@ $< $(MFLAGS) $(OPTMFLAGS)

iTunes.h:
	sdef /Applications/iTunes.app | sdp -fh --basename iTunes

clean:
	rm -f $(OFILES) $(OUT) iTunes.h
.PHONY: clean
