// 8 june 2017
#import "macgetalbums.h"

static BOOL optVerbose = NO;
static BOOL optShowLengths = NO;
static BOOL optShowCount = NO;
const char *optCollector = NULL;
// TODO option to spot tracks with either missing or duplicate album artwork (ScriptingBridge only)
// TODO option to build PDF

static void xlog(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	if (optVerbose)
		NSLogv(fmt, ap);
	va_end(ap);
}

static const char *collectors[] = {
	"iTunesLibraryCollector",
	"ScriptingBridgeCollector",
	NULL,
};

// TODO use objc_getRequiredClass() instead?
#define GETCLASS(c) objc_getClass(c)

static id<Collector> tryCollector(const char *class, Timer *timer, NSError **err)
{
	id<Collector> collector;
	Class<Collector> collectorClass;

	collectorClass = GETCLASS(class);
	xlog(@"trying collector %s", class);

	if (!amISigned && [collectorClass needsSigning]) {
		xlog(@"collector %s needs signing and we aren't signed; skipping", class);
		return nil;
	}

	collector = [[collectorClass alloc] initWithTimer:timer error:err];
	if (*err != nil) {
		xlog(@"error loading collector %s: %@; skipping",
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
	int i;

	fprintf(stderr, "usage: %s [-chlv] [-u collector]\n", argv0);
	fprintf(stderr, "  -c - show track and album count and total playing time and quit\n");
	fprintf(stderr, "  -h - show this help\n");
	fprintf(stderr, "  -l - show album lengths\n");
	fprintf(stderr, "  -u - use the specified collector\n");
	fprintf(stderr, "  -v - print verbose output\n");
	// TODO prettyprint this somehow
	fprintf(stderr, "known collectors; without -u, each is tried in this order:\n");
	for (i = 0; collectors[i] != NULL; i++) {
		Class<Collector> class;

		class = GETCLASS(collectors[i]);
		fprintf(stderr, " %s\n  %s\n",
			collectors[i],
			[[class collectorDescription] UTF8String]);
	}
	exit(1);
}

int main(int argc, char *argv[])
{
	id<Collector> collector;
	NSArray *tracks;
	NSUInteger trackCount;
	Timer *timer;
	BOOL signCheckSucceeded;
	Duration *totalDuration;
	NSError *err;
	int i, c;

	argv0 = argv[0];
	while ((c = getopt(argc, argv, ":chlu:v")) != -1)
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
		case 'u':
			optCollector = optarg;
			break;
		case '?':
			fprintf(stderr, "error: unknown option -%c\n", optopt);
			usage();
		case ':':
			fprintf(stderr, "error: option -%c requires an argument\n", optopt);
			usage();
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

	if (optCollector != NULL) {
		collector = nil;
		for (i = 0; collectors[i] != NULL; i++)
			if (strcmp(collectors[i], optCollector) == 0)
				break;
		if (collectors[i] == NULL) {
			// TODO print with quotes somehow
			fprintf(stderr, "error: unknown collector %s\n", optCollector);
			usage();
		}
		err = nil;
		collector = tryCollector(optCollector, timer, &err);
		if (collector == nil) {
			// TODO
			fprintf(stderr, "error: collector %s cannot be used\n", optCollector);
			return 1;
		}
		if (err != nil) {
			fprintf(stderr, "error trying collector %s: %s\n",
				optCollector,
				[[err description] UTF8String]);
			return 1;
		}
	} else {
		collector = nil;
		for (i = 0; collectors[i] != NULL; i++) {
			err = nil;
			collector = tryCollector(collectors[i], timer, &err);
			if (collector != nil)
				break;
		}
		if (collector == nil) {
			fprintf(stderr, "error: no iTunes collector could be used; cannot continue\n");
			return 1;
		}
	}

	tracks = [collector collectTracks];
	// TODO with Scripting Bridge this is ~1e-5 seconds?! is that correct?!
	xlog(@"time to collect tracks: %gs",
		[timer seconds:TimerCollect]);

	albums = [NSMutableSet new];
	totalDuration = [[Duration alloc] initWithMilliseconds:0];
	[timer start:TimerSort];
	trackCount = [tracks count];
	for (Item *track in tracks) {
		Item *existing;

		// We don't reuse track items for album items.
		// Instead we copy the first track in an album and then
		// combine the other tracks with that copy.
		existing = (Item *) [albums member:track];
		if (existing != nil)
			[existing combineWith:track];
		else {
			existing = [track copy];
			[albums addObject:existing];
			[existing release];		// and release our initial reference
		}
		[totalDuration add:[track length]];
	}
	[timer end];
	xlog(@"time to process tracks: %gs",
		[timer seconds:TimerSort]);
	[tracks release];
	[collector release];
	[timer release];

	if (optShowCount) {
		printf("%lu tracks %lu albums %s total time\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count],
			[[totalDuration description] UTF8String]);
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
	// TODO clean up
	return 0;
}
