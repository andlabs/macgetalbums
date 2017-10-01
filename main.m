// 8 june 2017
#import "macgetalbums.h"

@interface Opts : Options
- (BOOL)verbose;
- (BOOL)showLengths;
- (BOOL)showCount;
- (const char *)collector;
// TODO rename this variable optMinutesOnly (and Duration methods likewise)
- (BOOL)minutes;
// TODO rename this variable optArtworkCounts
- (BOOL)showArtwork;
- (BOOL)PDF;
- (const char *)sortBy;
// TODO reverse sort
@end

@implementation Opts

- (id)initWithArgv0:(const char *)argv0
{
	self = [super initWithArgv0:argv0];
	if (self) {
		[self addBoolOpt:@"v"
			helpText:@"print verbose output"
			accessor:@"verbose"];
		[self addBoolOpt:@"l"
			helpText:@"show album lengths"
			accessor:@"showLengths"];
		[self addBoolOpt:@"c"
			helpText:@"show track and album count and total playing time and quit"
			accessor:@"showCount"];
		[self addStringOpt:@"u"
			defaultValue:NULL
			helpText:@"use the specified collector"
			accessor:@"collector"];
		[self addBoolOpt:@"m"
			helpText:@"show times in minutes instead of hours and minutes"
			accessor:@"minutes"];
		[self addBoolOpt:@"a"
			helpText:@"show tracks that have missing or duplicate artwork (overrides -c and -p)"
			accessor:@"showArtwork"];
		[self addBoolOpt:@"p"
			helpText:@"write a PDF gallery of albums to stdout (overrides -c)"
			accessor:@"PDF"];
		[self addStringOpt:@"o"
			defaultValue:"year"
			helpText:@"-o - sort by the given key (year, length, none; default is year)"
			accessor:@"sortBy"];
	}
	return self;
}

@end

static Opts *options;

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
	if ([options collector] != NULL) {
		// we're trying one collector
		// we want errors to go straight to stderr
		// we also don't need preliminary log messages
		p.tryingMultiple = NO;
		p.log = xstderrprintf;
		collectors = singleCollectorArray([options collector]);
		if (collectors == nil) {
			fprintf(stderr, "error: unknown collector %s\n", [options collector]);
			*showUsage = YES;
			return nil;
		}
	} else {
		p.tryingMultiple = YES;
		p.log = xlog;
		collectors = defaultCollectorsArray();
	}
	p.isSigned = isSigned;
	p.forAlbumArtwork = [options showArtwork];
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

// you own the returned duration
// TODO this isn't really needed anymore... nor is the timer... (it used to sort tracks into albums but that's now part of the collection phase)
// TODO will adding the album durations give the same result?
static Duration *findTotalDuration(NSArray *tracks, Timer *timer)
{
	Duration *totalDuration;

	totalDuration = [[Duration alloc] initWithMilliseconds:0];
	[timer start:TimerSort];
	for (Track *t in tracks)
		[totalDuration add:[t length]];
	[timer end];
	return totalDuration;
}

static void showArtworkCounts(NSArray *tracks)
{
	for (Track *track in tracks)
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

	[options usage];
	// TODO integrate this somehow
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
	NSArray *albumsarr, *sortedAlbums;
	Timer *timer;
	Duration *totalDuration;
	NSError *err;
	int optind;

	options = [[Opts alloc] initWithArgv0:argv[0]];
	// TODO rename -v to -d for debug?
#if 0
	xx TODO
			if (strcmp(optSortBy, "year") != 0 &&
				strcmp(optSortBy, "length") != 0 &&
				strcmp(optSortBy, "none") != 0) {
				fprintf(stderr, "error: unknown sort key %s\n", optSortBy);
				usage();
			}
#endif
	optind = [options parse:argc argv:argv];
	argc -= optind;
	argv += optind;
	if (argc != 0)
		[options usage];

	if ([options verbose])
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
			[options usage];
		// tryCollectors() already printed error messages; we just need to quit now
		return 1;
	}
	xlogtimer(@"load iTunes library", timer, TimerLoad);

	tracks = [collector collectTracksAndAlbums:&albums withArtwork:[options PDF]];
	xlogtimer(@"collect tracks", timer, TimerCollect);
	xlogtimer(@"convert tracks to our internal data structure format", timer, TimerConvert);

	totalDuration = nil;
	sortedAlbums = nil;

	if ([options showArtwork]) {
		showArtworkCounts(tracks);
		goto done;
	}

	trackCount = [tracks count];
	// TODO this could be part of the collection stage...
	totalDuration = findTotalDuration(tracks, timer);
	// TODO no need to do this in -c mode
	// TODO allow sorting by artist
	// TODO allow using iTunes sort keys
	albumsarr = [albums allObjects];
	if (strcmp([options sortBy], "year") == 0)
		sortedAlbums = [albumsarr sortedArrayUsingSelector:@selector(compareForSortByYear:)];
	else if (strcmp([options sortBy], "length") == 0)
		sortedAlbums = [albumsarr sortedArrayUsingSelector:@selector(compareForSortByLength:)];
	else
		sortedAlbums = albumsarr;
	[sortedAlbums retain];
	xlogtimer(@"find total duration and sort albums in order", timer, TimerSort);

	if ([options PDF]) {
		CFDataRef data;
		const UInt8 *buf;
		CFIndex len;

		data = makePDF(sortedAlbums, [options showMinutes]);
		buf = CFDataGetBytePtr(data);
		len = CFDataGetLength(data);
		// TODO check error
		// TODO handle short writes by repeatedly calling write() (see also https://stackoverflow.com/questions/32683086/handling-incomplete-write-calls)
		write(1, buf, len);
		CFRelease(data);
		goto done;
	}

	if ([options showCount]) {
		NSString *totalstr;

		totalstr = [totalDuration stringWithOnlyMinutes:[option showMinutes]];
		xprintf(@"%lu tracks %lu albums %@ total time\n",
			(unsigned long) trackCount,
			(unsigned long) [albums count],
			totalstr);
		[totalstr release];
		goto done;
	}

	// TODO provide a custom separator option
	// TODO provide a custom sort option and default sort by year maybe
	for (Album *a in sortedAlbums) {
		xprintf(@"%ld\t%@\t%@",
			(long) ([a year]),
			[a artist],
			[a album]);
		if ([options showLengths]) {
			NSString *lengthstr;

			lengthstr = [[a length] stringWithOnlyMinutes:[options showMinutes]];
			xprintf(@"\t%@", lengthstr);
			[lengthstr release];
		}
		printf("\n");
	}

done:
	if (sortedAlbums != nil)
		[sortedAlbums release];
	if (totalDuration != nil)
		[totalDuration release];
	[albums release];
	[tracks release];
	[collector release];
	[timer release];
	[options release];
	return 0;
}
