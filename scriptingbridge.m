// 22 august 2017
#import "macgetalbums.h"

@interface ScriptingBridgeCollector : NSObject<Collector> {
	Timer *timer;
	iTunesApplication *iTunes;
}
@end

@implementation ScriptingBridgeCollector

+ (NSString *)collectorName
{
	return @"Scripting Bridge";
}

+ (BOOL)canRun
{
	return YES;
}

- (id)initWithTimer:(TImer *)t error:(NSError **)err
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

		item = trackToItem(track);
		[items addObject:item];
		[item release];		// and release the initial reference
	}

	// TODO is this release correct?
	[tracks release];
	return items;
}

@end
