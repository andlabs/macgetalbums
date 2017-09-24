// 22 august 2017
#import "macgetalbums.h"

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

- (NSArray *)collectTracks
{
	NSMutableArray *items;
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
		NSArray *allDiscNumbers;

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
		allDiscNumbers = [tracks arrayByApplyingSelector:@selector(discNumber)];
		// sadly we can't do this with artworks, as that'll just give uxxx a flat list of nTracks iTunesArtwork instances which won't work for whatever reason
		// alas, that leaves us with having to iterate below :/
		// TODO is there another way?
		[self->timer end];

		[self->timer start:TimerConvert];
		items = [[NSMutableArray alloc] initWithCapacity:nTracks];
		for (i = 0; i < nTracks; i++) {
			Item *item;
			NSString *trackArtist, *albumArtist;
			iTunesTrack *track;

#define typeAtIndex(t, a, i) ((t *) [(a) objectAtIndex:(i)])
#define stringAtIndex(a, i) typeAtIndex(NSString, a, i)
#define numberAtIndex(a, i) typeAtIndex(NSNumber, a, i)
#define boolAtIndex(a, i) [numberAtIndex(a, i) boolValue]
#define integerAtIndex(a, i) [numberAtIndex(a, i) integerValue]
#define doubleAtIndex(a, i) [numberAtIndex(a, i) doubleValue]
			trackArtist = stringAtIndex(allArtists, i);
			albumArtist = stringAtIndex(allAlbumArtists, i);
			if (boolAtIndex(allCompilations, i) != NO) {
				trackArtist = compilationArtist;
				albumArtist = compilationArtist;
			}
			track = (iTunesTrack *) [tracks objectAtIndex:i];
			item = [[Item alloc] initWithYear:integerAtIndex(allYears, i)
				trackArtist:trackArtist
				album:stringAtIndex(allAlbums, i)
				albumArtist:albumArtist
				lengthSeconds:doubleAtIndex(allDurations, i)
				title:stringAtIndex(allNames, i)
				trackNumber:integerAtIndex(allTrackNumbers, i)
				discNumber:integerAtIndex(allDiscNumbers, i)
				artworkCount:[[track artworks] count]];
			[items addObject:item];
			[item release];		// and release the initial reference
		}
		[self->timer end];
	}

	return items;
}

@end
