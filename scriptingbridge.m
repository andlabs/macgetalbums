// 22 august 2017
#import "macgetalbums.h"

static BOOL isRealFirstTrack(id<NSObject> candidate, Album *album)
{
	iTunesTrack *a, *b;

	a = (iTunesTrack *) candidate;
	b = (iTunesTrack *) [album firstTrack];
	if ([a discNumber] > [b discNumber])
		return NO;
	if ([a discNumber] < [b discNumber])
		return YES;
	// same disc; earlier track?
	return [a trackNumber] < [b trackNumber];
}

static void addArtwork(Album *a)
{
	iTunesTrack *firstTrack;
	SBElementArray *artworks;
	iTunesArtwork *artwork;

	firstTrack = (iTunesTrack *) [a firstTrack];
	artworks = [firstTrack artworks];
	artwork = nil;
	if ([artworks count] > 0)
		artwork = (iTunesArtwork *) [artworks objectAtIndex:0];
	if (artwork != nil) {
		// TODO why is -[artwork data] a NSAppleEventDescriptor?
		NSImage *img;

		img = [[NSImage alloc] initWithData:[artwork rawData]];
		[a setFirstArtwork:img];
		[img release];
	}
}

// TODO figure out how far back we can have ivars in @implementation
@implementation ScriptingBridgeCollector {
	Timer *timer;
	iTunesApplication *iTunes;
}

+ (NSString *)collectorDescription
{
	return @"Scripting Bridge (uses AppleScript to talk to iTunes; will launch iTunes as a result)";
}

+ (BOOL)needsSigning
{
	return NO;
}

+ (BOOL)canGetArtworkCount
{
	return YES;
}

- (id)initWithTimer:(Timer *)t error:(NSError **)err
{
	self = [super init];
	if (self) {
		self->timer = t;
		[self->timer retain];

		[self->timer start:TimerLoad];
		// Apple's docs say that this version will launch the application (to be able to send messages to it), but the init form doesn't have this clause.
		// However, the headers say this is equivalent to calling init followed by autorelease (the usual convention for methods like this).
		// Let's be safe and use the autorelease version; we can always retain it ourselves.
		self->iTunes = (iTunesApplication *) [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
		// TODO should we call [self->iTunes get] to get an accurate launch time in case iTunes isn't running, or will that not work?
		[self->iTunes retain];
		[self->timer end];

		// TODO should we just use [self->iTunes lastError]?
		*err = nil;
	}
	return self;
}

- (void)dealloc
{
	[self->iTunes release];
	[self->timer release];
	[super dealloc];
}

- (Collection *)collectWithParams:(NSDictionary *)p
{
	Collection *c;
	NSUInteger i, nTracks;

	@autoreleasepool {
		// all of these variables are either autoreleased or not owned by us, judging from sample code and Cocoa memory management rules and assumptions about what methods get called by sdp-generated headers
		SBElementArray *tracks;
		NSArray *allArtists;
		NSArray *allAlbumArtists;
		NSArray *allCompilations;
		NSArray *allYears;
		NSArray *allAlbums;
		NSArray *allDurations;
		NSArray *allNames;
		NSArray *allTrackNumbers;
		NSArray *allTrackCounts;
		NSArray *allDiscNumbers;
		NSArray *allDiscCounts;

		[self->timer start:TimerCollect];
		// TODO will this include non-music items?
		tracks = [self->iTunes tracks];
		nTracks = [tracks count];
		allArtists = [tracks arrayByApplyingSelector:@selector(artist)];
		allAlbumArtists = [tracks arrayByApplyingSelector:@selector(albumArtist)];
		allCompilations = [tracks arrayByApplyingSelector:@selector(compilation)];
		allYears = [tracks arrayByApplyingSelector:@selector(year)];
		allAlbums = [tracks arrayByApplyingSelector:@selector(album)];
		allDurations = [tracks arrayByApplyingSelector:@selector(duration)];
		allNames = [tracks arrayByApplyingSelector:@selector(name)];
		allTrackNumbers = [tracks arrayByApplyingSelector:@selector(trackNumber)];
		allTrackCounts = [tracks arrayByApplyingSelector:@selector(trackCount)];
		allDiscNumbers = [tracks arrayByApplyingSelector:@selector(discNumber)];
		allDiscCounts = [tracks arrayByApplyingSelector:@selector(discCount)];
		// sadly we can't do this with artworks, as that'll just give uxxx a flat list of nTracks iTunesArtwork instances which won't work for whatever reason
		// alas, that leaves us with having to iterate below :/
		// TODO is there another way?
		[self->timer end];

		[self->timer start:TimerConvert];
		c = [[Collection alloc] initWithParams:p
			trackCount:nTracks];
		for (i = 0; i < nTracks; i++) {
			iTunesTrack *track;
			Track *trackOut;
			struct trackParams p;

			track = (iTunesTrack *) [tracks objectAtIndex:i];

			memset(&p, 0, sizeof (struct trackParams));
#define typeAtIndex(t, a, i) ((t *) [(a) objectAtIndex:(i)])
#define stringAtIndex(a, i) typeAtIndex(NSString, a, i)
#define numberAtIndex(a, i) typeAtIndex(NSNumber, a, i)
#define boolAtIndex(a, i) [numberAtIndex(a, i) boolValue]
#define integerAtIndex(a, i) [numberAtIndex(a, i) integerValue]
#define doubleAtIndex(a, i) [numberAtIndex(a, i) doubleValue]
			p.year = integerAtIndex(allYears, i);
			p.trackArtist = stringAtIndex(allArtists, i);
			p.albumArtist = stringAtIndex(allAlbumArtists, i);
			if (boolAtIndex(allCompilations, i) != NO) {
				p.trackArtist = compilationArtist;
				p.albumArtist = compilationArtist;
			}
			p.album = stringAtIndex(allAlbums, i);
			p.title = stringAtIndex(allNames, i);
			p.trackNumber = integerAtIndex(allTrackNumbers, i);
			p.trackCount = integerAtIndex(allTrackCounts, i);
			p.discNumber = integerAtIndex(allDiscNumbers, i);
			p.discCount = integerAtIndex(allDiscCounts, i);
			p.artworkCount = [[track artworks] count];
			trackOut = [[Track alloc] initWithParams:&p
				lengthSeconds:doubleAtIndex(allDurations, i)];

			[c addTrack:trackOut
				withFirstTrack:track
				isRealFirstTrackFunc:isRealFirstTrack];
			[trackOut release];		// and release the initial reference
		}

		// now collect album artworks
		// even if we aren't, we should release our firstTracks anyway
		[c addArtworksAndReleaseFirstTracks:addArtwork];
		[self->timer end];
	}

	return c;
}

@end
