// 8 june 2017
#import "macgetalbums.h"

static BOOL optVerbose = NO;
static BOOL optShowLengths = NO;
static BOOL optShowCount = NO;
// TODO option to force a specific collector

static void xlog(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	if (optVerbose)
		NSLogv(fmt, ap);
	va_end(ap);
}

// TODO why can't this be const?
static NSString *collectors[] = {
	@"iTunesLibraryCollector",
	@"ScriptingBridgeCollector",
	nil,
};

static id<Collector> tryCollector(NSString *class, Timer *timer)
{
	id<Collector> collector;
	Class<Collector> collectorClass;
	NSError *err = nil;

	collectorClass = NSClassFromString(class);
	xlog(@"trying collector %@", class);

	if (!amISigned && [collectorClass needsSigning]) {
		xlog(@"collector %@ needs signing and we aren't signed; skipping", class);
		return nil;
	}

	collector = [[collectorClass alloc] initWithTimer:timer error:&err];
	if (err != nil) {
		xlog(@"error loading collector %@: %@; skipping",
			class, err);
		// TODO release err?
		[collector release];
		return nil;
	}
	xlog(@"time to load iTunes library: %gs",
		[timer seconds:TimerLoad]);
	return collector;
}

NSMutableSet *albums = nil;

const char *argv0;

void usage(void)
{
	fprintf(stderr, "usage: %s [-chlv]\n", argv0);
	fprintf(stderr, "  -c - show track and album count and quit\n");
	fprintf(stderr, "  -h - show this help\n");
	fprintf(stderr, "  -l - show album lengths\n");
	fprintf(stderr, "  -v - print verbose output\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	id<Collector> collector;
	NSArray *tracks;
	NSUInteger trackCount;
	Timer *timer;
	BOOL signCheckSucceeded;
	int i, c;

	argv0 = argv[0];
	while ((c = getopt(argc, argv, ":chlv")) != -1)
		switch (c) {
		case 'v':
			// TODO rename to -d for debug?
			optVerbose = YES;
			break;
		case 'l':
			optShowLengths = YES;
			break;
		case 'c':
			optShowCount = YES;
			break;
		case '?':
			fprintf(stderr, "error: unknown option -%c\n", optopt);
			// fall through
		case 'h':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;
	if (argc != 0)
		usage();

	signCheckSucceeded = checkIfSigned();
	if (!signCheckSucceeded)
		xlog(@"signed-code checking failed with error %d; assuming not signed", (int) amISignedErr);
	else if (amISigned)
		xlog(@"we are signed");
	else
		xlog(@"we are not signed");

	timer = [Timer new];

	collector = nil;
	for (i = 0; collectors[i] != nil; i++) {
		collector = tryCollector(collectors[i], timer);
		if (collector != nil)
			break;
	}
	if (collector == nil) {
		fprintf(stderr, "error: no iTunes collector could be used; cannot continue\n");
		return 1;
	}

	tracks = [collector collectTracks];
	// TODO with Scripting Bridge this is ~1e-5 seconds?! is that correct?!
	xlog(@"time to collect tracks: %gs",
		[timer seconds:TimerCollect]);

	albums = [NSMutableSet new];
	[timer start:TimerSort];
	trackCount = [tracks count];
	for (Item *track in tracks) {
		Item *existing;

		// If the album is already in the set, update the year and
		// the length; otherwise, just add the track to start off this
		// new album (effectively turning a track Item into an
		// album Item).
		existing = (Item *) [albums member:track];
		if (existing != nil) {
			// We want to take the earliest release date, to
			// reflect the original release of this album.
			if ([existing year] > [track year])
				[existing setYear:[track year]];
			[[existing length] add:[track length]];
			continue;
		}
		[albums addObject:track];
	}
	[timer end];
	xlog(@"time to process tracks: %gs",
		[timer seconds:TimerSort]);
	[tracks release];
	[collector release];
	[timer release];

	if (optShowCount) {
		printf("%lu tracks %lu albums\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count]);
		goto done;
	}

	// TODO is tab safe to use?
	// TODO switch to foreach
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		Item *t = (Item *) obj;

		printf("%ld\t%s\t%s",
			(long) ([t year]),
			[[t artist] UTF8String],
			[[t album] UTF8String]);
		if (optShowLengths)
			printf("\t%s",
				[[[t length] description] UTF8String]);
		printf("\n");
	}];

done:
	// TODO clean up here?
	return 0;
}
