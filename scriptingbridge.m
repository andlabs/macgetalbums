// 22 august 2017
#import "macgetalbums.h"

@interface ScriptingBridgeCollector : NSObject<Collector> {
}
@end

static Item *trackToItem(iTunesTrack *track)
{
	Item *item;

	item = [Item new];
	item.Year = [track year];
	item.Artist = [track albumArtist];
	if (item.Artist == nil) {
		fprintf(stderr, "TODO\n");
		exit(1);
	}
	if ([item.Artist isEqual:@""])
		item.Artist = [track artist];
	item.Album = [track album];
	[item handleOverrides];
	item.Length = [track duration];
	return item;
}

@implementation ScriptingBridgeCollector

+ (NSString *)collectorName
{
	return @"Scripting Bridge";
}

+ (BOOL)canRun
{
	return YES;
}

// TODO split this into two functions
- (NSArray *)collectTracks:(double *)duration;
{
	iTunesApplication *iTunes;
	SBElementArray *tracks;
	NSMutableArray *items;
	Timer *timer;

	iTunes = (iTunesApplication *) [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

	timer = [Timer new];
	[timer start];
	tracks = [iTunes tracks];
	[timer end];
	if (duration != NULL)
		*duration = [timer seconds];
	[timer release];

	items = [[NSMutableArray alloc] initWithCapacity:[tracks count]];
	// SBElementArray is a subclass of NSMutableArray so this will work
	for (iTunesTrack *track in tracks) {
		Item *item;

		item = trackToItem(track);
		[items addObject:item];
		[item release];		// and release the initial reference
	}

	// TODO is this first release correct?
	[tracks release];
	[iTunes release];
	return items;
}

@end
