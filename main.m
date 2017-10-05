// 8 june 2017
#import "macgetalbums.h"

@interface Options : FlagSet
@end

AddBoolFlag(Options, verbose,
	@"v", @"print verbose output")
AddBoolFlag(Options, showLengths,
	@"l", @"show album lengths")
AddBoolFlag(Options, showCount,
	@"c", @"show track and album count and total playing time and quit")
AddStringFlag(Options, collector,
	@"u", NULL, @"use the specified collector")
// TODO rename this variable optMinutesOnly (and Duration methods likewise)
AddBoolFlag(Options, minutes,
	@"m", @"show times in minutes instead of hours and minutes")
// TODO rename this variable optArtworkCounts
AddBoolFlag(Options, showArtwork,
	@"a", @"show tracks that have missing or duplicate artwork (overrides -c and -p)")
AddBoolFlag(Options, PDF, @"p", @"write a PDF gallery of albums to stdout (overrides -c)")
// TODO manage memory for the sort list properly
// TODO also unify the terminology (sortBy, sortMode, sortMethod, sortKey)
AddStringFlag(Options, sortBy,
	@"o", "year", ([NSString stringWithFormat:@"sort by the given key (%@; default is year)", [Collection copySortModeList]]))
AddBoolFlag(Options, reverseSort,
	@"r", @"reverse sort order")
// TODO excludeArtistRegexp with name -xa
AddStringFlag(Options, excludeAlbumsRegexp,
	@"xb", NULL, @"if specified, exclude albums whose names match the given regexp")
// TODO case-insensitive regexp match
// TODO how should these regex options affect -c?

static BOOL usagePrintCollectors(NSString *name, Class<Collector> class, void *data)
{
	NSMutableString *str = (NSMutableString *) data;

	[str appendFormat:@" %@\n  %@\n",
		name, [class collectorDescription]];
	return NO;
}

@implementation Options

+ (NSString *)copyUsageTrailingLines
{
	NSMutableString *ret;
	NSArray *knownCollectors;

	ret = [NSMutableString new];
	// TODO prettyprint this somehow
	[ret appendString:@"known collectors; without -u, each is tried in this order:\n"];
	knownCollectors = defaultCollectorsArray();
	foreachCollector(knownCollectors, usagePrintCollectors, ret);
	[knownCollectors release];
	return ret;
}

@end

static Options *options;

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

int main(int argc, char *argv[])
{
	BOOL isSigned;
	BOOL showUsage;
	id<Collector> collector;
	Collection *c;
	NSMutableDictionary *params;
	NSArray *albums;
	Timer *timer;
	NSError *err;
	int optind;

	params = [NSMutableDictionary new];

	options = [[Options alloc] initWithArgv0:argv[0]];
	// TODO rename -v to -d for debug?
	optind = [options parseArgc:argc argv:argv];
	argc -= optind;
	argv += optind;
	if (argc != 0)
		[options usage];
	if (![Collection isValidSortMode:[options sortBy]]) {
		fprintf(stderr, "error: unknown sort key %s\n", [options sortBy]);
		[options usage];
	}
	if ([options excludeAlbumsRegexp] != NULL) {
		Regexp *r;

		r = [[Regexp alloc] initWithRegexp:[options excludeAlbumsRegexp]
			caseInsensitive:NO
			error:&err];
		if (err != nil) {
			[r release];
			xfprintf(stderr, @"error parsing -xb regexp %s: %@\n", [options excludeAlbumsRegexp], err);
			[err release];
			[options usage];
		}
		[params setObject:r forKey:CollectionParamsExcludeAlbumsRegexpKey];
		[r release];
	}

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

	// only PDFs need the artwork
	if ([options PDF])
		[params setObject:[NSNumber numberWithBool:YES]
			forKey:CollectionParamsIncludeArtworkKey];

	c = [collector collectWithParams:params];
	xlogtimer(@"collect tracks", timer, TimerCollect);
	xlogtimer(@"convert tracks to our internal data structure format", timer, TimerConvert);

	albums = nil;

	if ([options showArtwork]) {
		showArtworkCounts([c tracks]);
		goto done;
	}

	[timer start:TimerSort];
	// TODO no need to do this in -c mode
	// TODO allow using iTunes sort keys
	// TODO should sorts be case-insensitive, or should that be optional, or not at all?
	albums = [c copySortedAlbums:[options sortBy]
		reverseSort:[options reverseSort]];
	[timer end];
	xlogtimer(@"sort and filter albums", timer, TimerSort);

	if ([options PDF]) {
		CFDataRef data;
		const UInt8 *buf;
		CFIndex len;

		data = makePDF(albums, [options minutes]);
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

		totalstr = [[c totalDuration] stringWithOnlyMinutes:[options minutes]];
		xprintf(@"%lu tracks %lu albums %@ total time\n",
			(unsigned long) [[c tracks] count],
			(unsigned long) [[c albums] count],
			totalstr);
		[totalstr release];
		goto done;
	}

	// TODO provide a custom separator option
	// TODO provide a custom sort option and default sort by year maybe
	for (Album *a in albums) {
		xprintf(@"%ld\t%@\t%@",
			(long) ([a year]),
			[a artist],
			[a album]);
		if ([options showLengths]) {
			NSString *lengthstr;

			lengthstr = [[a length] stringWithOnlyMinutes:[options minutes]];
			xprintf(@"\t%@", lengthstr);
			[lengthstr release];
		}
		printf("\n");
	}

done:
	if (albums != nil)
		[albums release];
	[c release];
	[collector release];
	[timer release];
	[options release];
	[params release];
	return 0;
}
