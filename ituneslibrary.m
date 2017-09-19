// 3 september 2017
#import "macgetalbums.h"

// To avoid a build-time dependency on iTunesLibrary.framework, recreate the relevant functionality with protocols so we don't have to include the real headers.
// Thanks to dexter0 in irc.freenode.net/#macdev.
@protocol ourITLibArtist<NSObject>
- (NSString *)name;
@end

@protocol ourITLibAlbum<NSObject>
- (NSString *)title;
- (NSString *)albumArtist;
@end

@protocol ourITLibMediaItem<NSObject>
- (NSString *)title;
- (id<ourITLibArtist>)artist;
- (id<ourITLibAlbum>)album;
- (NSUInteger)totalTime;
- (NSDate *)releaseDate;
- (NSUInteger)year;
@end

@protocol ourITLibrary<NSObject>
- (instancetype)initWithAPIVersion:(NSString *)version error:(NSError **)err;
- (NSArray *)allMediaItems;
@end

// TODO figure out how far back we can have ivars in @implementation
@implementation iTunesLibraryCollector {
}

+ (NSString *)collectorName
{
	return @"iTunesLibrary Framework";
}

+ (BOOL)canRun
{
	// TODO
	return NO;

	// TODO instead of calling this, test it at startup
	return amISigned;
}

- (id)initWithTimer:(Timer *)t error:(NSError **)err
{
	self = [super init];
	if (self) {
		// TODO
	}
	return self;
}

- (void)dealloc
{
	// TODO
	[super dealloc];
}

// TODO make this an instance stuff
- (NSArray *)collectTracks
{
abort();return nil;
#if 0//TODO
	NSBundle *framework;
	Class libraryClass;
	id<ourITLibrary> library;
	NSError *err;

	framework = [[NSBundle alloc] initWithPath:@"/Library/Frameworks/iTunesLibrary.framework"];
	if (framework == nil) {
		NSLog(@"failed to create NSBundle for iTunesLibrary.framework");
		return 1;
	}
	if ([framework loadAndReturnError:&err] == NO) {
		NSLog(@"failed to load iTunesLibrary.framework: %@", err);
		return 1;
	}
	libraryClass = [framework classNamed:@"ITLibrary"];
	if (libraryClass == nil) {
		NSLog(@"failed to load ITLibrary class");
		return 1;
	}

	library = (id<ourITLibrary>) [libraryClass alloc];
	library = [library initWithAPIVersion:@"1.0" error:&err];
	if (library == nil) {
		NSLog(@"error initializing library: %@", err);
		return 1;
	}
	NSLog(@"count: %lu", (unsigned long) [[library allMediaItems] count]);
	// TODO does this only cover music or not? compare to the ScriptingBridge code
	for (id<ourITLibMediaItem> track in [library allMediaItems]) {
		NSLog(@"%@ | %@ | %@ | %@ | %lu(%@) | %lu",
			[track title],
			[track artist],
			[[track album] title],
			[[track album] albumArtist],
			(unsigned long) [track year],
			[track releaseDate],
			(unsigned long) [track totalTime]);
	}
	[library release];

	if ([framework unload] == NO)
		NSLog(@"warning: failed to unload iTunesLibrary.framework");
	[framework release];
	return nil;
#endif
}

@end
