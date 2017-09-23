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

// potential TODO: have a xprintf() and xfprintf() too

static void xlogtimer(NSString *msg, Timer *timer, int which)
{
	NSString *ts;

	ts = [timer stringFor:which];
	xlog(@"time to %@: %@", msg, ts);
	[ts release];
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
		[collector release];
		return nil;
	}
	return collector;
}

// you own the returned NSSet
static NSSet *sortIntoAlbums(NSArray *tracks, Timer *timer, Duration **totalDuration)
{
	NSMutableSet *albums;

	albums = [[NSMutableSet alloc] initWithCapacity:[tracks count]];
	*totalDuration = [[Duration alloc] initWithMilliseconds:0];
	[timer start:TimerSort];
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
		[*totalDuration add:[track length]];
	}
	[timer end];
	return albums;
}

static void showArtworkCounts(NSArray *tracks)
{
	for (Item *track in tracks)
		if ([track artworkCount] != 1) {
			NSString *f;

			f = [track formattedNumberTitleArtistAlbum];
			printf("%8lu %s\n",
				(unsigned long) [track artworkCount],
				[f UTF8String]);
			[f release];
		}
}

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
	NSSet *albums;
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
		} else
			xlog(@"we are not signed");
	else
		xlog(@"we are signed");

	timer = [Timer new];

	// TODO this needs massive cleanup
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
	xlogtimer(@"load iTunes library", timer, TimerLoad);

	tracks = [collector collectTracks];
	xlogtimer(@"collect tracks", timer, TimerCollect);
	xlogtimer(@"convert tracks to our internal data structure format", timer, TimerConvert);

	albums = nil;
	totalDuration = nil;

	if (optArtwork) {
		showArtworkCounts(tracks);
		goto done;
	}

	trackCount = [tracks count];
	albums = sortIntoAlbums(tracks, timer, &totalDuration);
	xlogtimer(@"process tracks", timer, TimerSort);

	if (optShowCount) {
		NSString *totalstr;

		totalstr = [totalDuration stringWithOnlyMinutes:optMinutes];
		printf("%lu tracks %lu albums %s total time\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count],
			[totalstr UTF8String]);
		[totalstr release];
		goto done;
	}

	// TODO provide a custom separator option
	for (Item *a in albums) {
		printf("%ld\t%s\t%s",
			(long) ([a year]),
			[[a artist] UTF8String],
			[[a album] UTF8String]);
		if (optShowLengths) {
			NSString *lengthstr;

			lengthstr = [[a length] stringWithOnlyMinutes:optMinutes];
			printf("\t%s", [lengthstr UTF8String]);
			[lengthstr release];
		}
		printf("\n");
	}

done:
	if (totalDuration != nil)
		[totalDuration release];
	if (albums != nil)
		[albums release];
	[tracks release];
	[collector release];
	[timer release];
	return 0;
}
