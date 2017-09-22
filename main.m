// 8 june 2017
#import "macgetalbums.h"

static BOOL optVerbose = NO;
static BOOL optShowLengths = NO;
static BOOL optShowCount = NO;
const char *optCollector = NULL;
static BOOL optMinutes = NO;
static BOOL optArtwork = NO;
// TODO option to build PDF

// TODO make sure this isn't global
static BOOL isSigned = NO;

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

#define GETCLASS(c) objc_getRequiredClass(c)

// you own the NSError here
static id<Collector> tryCollector(const char *class, BOOL forAlbumArtwork, Timer *timer, NSError **err)
{
	id<Collector> collector;
	Class<Collector> collectorClass;

	collectorClass = GETCLASS(class);
	if (!isSigned && [collectorClass needsSigning]) {
		*err = makeError(ErrSigningNeeded, class);
		return nil;
	}
	if (forAlbumArtwork && ![collectorClass canGetArtworkCount]) {
		*err = makeError(ErrCannotCollectArtwork, class);
		return nil;
	}

	collector = [[collectorClass alloc] initWithTimer:timer error:err];
	if (*err != nil) {
		[*err retain];
		[collector release];
		return nil;
	}
	return collector;
}

NSMutableSet *albums = nil;

const char *argv0;

void usage(void)
{
	int i;

	fprintf(stderr, "usage: %s [-achlmv] [-u collector]\n", argv0);
	fprintf(stderr, "  -a - show tracks that have missing or duplicate artwork (overrides -c)\n");
	fprintf(stderr, "  -c - show track and album count and total playing time and quit\n");
	fprintf(stderr, "  -h - show this help\n");
	fprintf(stderr, "  -l - show album lengths\n");
	fprintf(stderr, "  -m - show times in minutes instead of hours and minutes\n");
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
	Duration *totalDuration;
	NSError *err;
	int i, c;

	argv0 = argv[0];
	while ((c = getopt(argc, argv, ":achlmu:v")) != -1)
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
		case 'm':
			optMinutes = YES;
			break;
		case 'a':
			optArtwork = YES;
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

	isSigned = checkIfSigned(&err);
	if (!isSigned)
		if (err != nil) {
			xlog(@"signed-code checking failed: %@; assuming not signed", err);
			[err release];
			err = nil;
		} else
			xlog(@"we are not signed");
	else
		xlog(@"we are signed");

	timer = [Timer new];

	// TODO this and tryCollector() need massive cleanup
	if (optCollector != NULL) {
		for (i = 0; collectors[i] != NULL; i++)
			if (strcmp(collectors[i], optCollector) == 0)
				break;
		if (collectors[i] == NULL) {
			fprintf(stderr, "error: unknown collector %s\n", optCollector);
			usage();
		}
		err = nil;
		collector = tryCollector(optCollector, optArtwork, timer, &err);
		if (err != nil) {
			@autoreleasepool {
				fprintf(stderr, "error trying collector %s: %s\n",
					optCollector,
					[[err description] UTF8String]);
				[err release];
			}
			return 1;
		}
	} else {
		collector = nil;
		for (i = 0; collectors[i] != NULL; i++) {
			xlog(@"trying collector %s", collectors[i]);
			err = nil;
			collector = tryCollector(collectors[i], optArtwork, timer, &err);
			if (err != nil) {
				xlog(@"error trying collector %s: %@; skipping\n",
					collectors[i], err);
				[err release];
				continue;
			}
			break;
		}
		if (collector == nil) {
			fprintf(stderr, "error: no iTunes collector could be used; cannot continue\n");
			return 1;
		}
	}
	xlog(@"time to load iTunes library: %s",
		[[timer stringFor:TimerLoad] UTF8String]);

	tracks = [collector collectTracks];
	xlog(@"time to collect tracks: %s",
		[[timer stringFor:TimerCollect] UTF8String]);
	xlog(@"time to convert tracks to our internal data structure format: %s",
		[[timer stringFor:TimerConvert] UTF8String]);

	if (optArtwork) {
		for (Item *track in tracks)
			if ([track artworkCount] != 1)
				printf("%8lu %s\n",
					(unsigned long) [track artworkCount],
					[[track formattedNumberTitleArtistAlbum] UTF8String]);
		// TODO implement proper cleanup and then goto done
		return 0;
	}

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
	xlog(@"time to process tracks: %s",
		[[timer stringFor:TimerSort] UTF8String]);
	[tracks release];
	[collector release];
	[timer release];

	if (optShowCount) {
		printf("%lu tracks %lu albums %s total time\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count],
			[[totalDuration stringWithOnlyMinutes:optMinutes] UTF8String]);
		goto done;
	}

	// TODO is tab safe to use? provide a custom separator option
	// TODO switch to foreach
	// TODO change variable name from t to a or album
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		Item *t = (Item *) obj;

		printf("%ld\t%s\t%s",
			(long) ([t year]),
			[[t artist] UTF8String],
			[[t album] UTF8String]);
		if (optShowLengths)
			printf("\t%s",
				[[[t length] stringWithOnlyMinutes:optMinutes] UTF8String]);
		printf("\n");
	}];

done:
	// TODO clean up
	return 0;
}
