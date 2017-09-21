// 22 august 2017
#import "macgetalbums.h"

// TODO determine proper memory management

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
		// TODO should we call get on this?
		// TODO include the retain in the timer, just to be safe?
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
	SBElementArray *tracks;
	NSMutableArray *items;

	[self->timer start:TimerCollect];
	tracks = [self->iTunes tracks];
	[self->timer end];

	items = [[NSMutableArray alloc] initWithCapacity:[tracks count]];
	// SBElementArray is a subclass of NSMutableArray so this will work
	for (iTunesTrack *track in tracks) {
		Item *item;
		NSString *trackArtist, *albumArtist;

		trackArtist = [track artist];
		albumArtist = [track albumArtist];
		// TODO this always returns NO for some reason
		if ([track compilation]) {
			trackArtist = compilationArtist;
			albumArtist = compilationArtist;
		}
		item = [[Item alloc] initWithYear:[track year]
			trackArtist:[track artist]
			album:[track album]
			albumArtist:[track albumArtist]
			lengthSeconds:[track duration]
			title:[track name]
			trackNumber:[track trackNumber]
			discNumber:[track discNumber]
			artworkCount:[[track artworks] count]];
		[items addObject:item];
		[item release];		// and release the initial reference
	}

	// TODO is this release correct?
	[tracks release];
	return items;
}

@end
