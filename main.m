// 8 june 2017
#import "macgetalbums.h"

static BOOL optVerbose = NO;
static BOOL optShowLengths = NO;
static BOOL optShowCount = NO;
const char *optCollector = NULL;
static BOOL optMinutes = NO;
static BOOL optArtwork = NO;
// TODO option to build PDF

static id<Collector> tryCollector(NSString *name, Class<Collector> class, BOOL isSigned, BOOL forAlbumArtwork, Timer *timer, NSError **err)
{
	id<Collector> collector;

	if (!isSigned && [class needsSigning]) {
		*err = makeError(ErrSigningNeeded, name);
		return nil;
	}
	if (forAlbumArtwork && ![class canGetArtworkCount]) {
		*err = makeError(ErrCannotCollectArtwork, name);
		return nil;
	}

	collector = [[class alloc] initWithTimer:timer error:err];
	if (*err != nil) {
		[collector release];
		return nil;
	}
	return collector;
}

struct tryCollectorsParams {
	BOOL tryingMultiple;
	void (*log)(NSString *, ...);
	BOOL isSigned;
	BOOL forAlbumArtwork;
	Timer *timer;
	id<Collector> collector;
};

static BOOL tryCollectorsForEach(NSString *name, Class<Collector> class, void *data)
{
	struct tryCollectorsParams *p = (struct tryCollectorsParams *) data;
	NSString *skipping;
	NSError *err;

	if (p->tryingMultiple)
		(*(p->log))(@"trying collector %@", name);

	err = nil;
	p->collector = tryCollector(name, class,
		p->isSigned, p->forAlbumArtwork,
		p->timer, &err);
	if (err != nil) {
		skipping = @"\n";
		if (p->tryingMultiple)
			// no need for a newline in this case; the function pointed to by p->log will do it for us
			skipping = @"; skipping";
		(*(p->log))(@"error trying collector %@: %@%@",
			name, err, skipping);
		[err release];
		return NO;
	}
	return YES;
}

static id<Collector> tryCollectors(BOOL isSigned, Timer *timer, BOOL *showUsage)
{
	struct tryCollectorsParams p;
	NSArray *collectors;

	*showUsage = NO;
	memset(&p, 0, sizeof (struct tryCollectorsParams));
	if (optCollector != NULL) {
		// we're trying one collector
		// we want errors to go straight to stderr
		// we also don't need preliminary log messages
		p.tryingMultiple = NO;
		p.log = xstderrprintf;
		collectors = singleCollectorArray(optCollector);
		if (collectors == nil) {
			fprintf(stderr, "error: unknown collector %s\n", optCollector);
			*showUsage = YES;
			return nil;
		}
	} else {
		p.tryingMultiple = YES;
		p.log = xlog;
		collectors = defaultCollectorsArray();
	}
	p.isSigned = isSigned;
	p.forAlbumArtwork = optArtwork;
	p.timer = timer;
	foreachCollector(collectors, tryCollectorsForEach, &p);
	[collectors release];
	if (p.collector == nil) {
		// when trying only one collector, tryCollectorsForEach() already prints an error message
		// when trying multiple, there's no error message, so print one now
		if (p.tryingMultiple)
			fprintf(stderr, "error: no iTunes collector could be used; cannot continue\n");
		return nil;
	}
	return p.collector;
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
			xprintf(@"%8lu %@\n",
				(unsigned long) [track artworkCount],
				f);
			[f release];
		}
}

const char *argv0;

static BOOL usagePrintCollectors(NSString *name, Class<Collector> class, void *data)
{
	xfprintf(stderr, @" %@\n  %@\n",
		name, [class collectorDescription]);
	return NO;
}

void usage(void)
{
	NSArray *knownCollectors;

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
	knownCollectors = defaultCollectorsArray();
	foreachCollector(knownCollectors, usagePrintCollectors, NULL);
	[knownCollectors release];
	exit(1);
}

int main(int argc, char *argv[])
{
	BOOL isSigned;
	BOOL showUsage;
	id<Collector> collector;
	NSArray *tracks;
	NSUInteger trackCount;
	NSSet *albums;
	Timer *timer;
	Duration *totalDuration;
	NSError *err;
	int c;

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

	if (optVerbose)
		suppressLogs = NO;

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

	collector = tryCollectors(isSigned, timer, &showUsage);
	if (collector == nil) {
		if (showUsage)
			usage();
		// tryCollectors() already printed error messages; we just need to quit now
		return 1;
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
		xprintf(@"%lu tracks %lu albums %@ total time\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count],
			totalstr);
		[totalstr release];
		goto done;
	}

	// TODO provide a custom separator option
	for (Item *a in albums) {
		xprintf(@"%ld\t%@\t%@",
			(long) ([a year]),
			[a artist],
			[a album]);
		if (optShowLengths) {
			NSString *lengthstr;

			lengthstr = [[a length] stringWithOnlyMinutes:optMinutes];
			xprintf(@"\t%@", lengthstr);
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
