// 3 september 2017
#import "macgetalbums.h"

// To avoid a build-time dependency on iTunesLibrary.framework, recreate the relevant functionality with protocols so we don't have to include the real headers.
// Thanks to dexter0 in irc.freenode.net/#macdev.
@protocol ourITLibArtist<NSObject>
- (NSString *)name;				// does not return retained
@end

@protocol ourITLibAlbum<NSObject>
- (NSString *)title;				// does not return retained
- (NSString *)albumArtist;			// does not return retained
- (BOOL)isCompilation;
- (NSUInteger)discNumber;
@end

@protocol ourITLibMediaItem<NSObject>
- (NSString *)title;				// does not return retained
- (id<ourITLibArtist>)artist;		// does not return retained
- (id<ourITLibAlbum>)album;		// does not return retained
- (NSUInteger)totalTime;
- (NSUInteger)year;
- (NSUInteger)trackNumber;
@end

@protocol ourITLibrary<NSObject>
- (instancetype)initWithAPIVersion:(NSString *)version error:(NSError **)err;
- (NSArray *)allMediaItems;		// does not return retained
@end

#define frameworkPath @"/Library/Frameworks/iTunesLibrary.framework"

// TODO figure out how far back we can have ivars in @implementation
@implementation iTunesLibraryCollector {
	Timer *timer;
	NSBundle *framework;
	id<ourITLibrary> library;
}

+ (NSString *)collectorDescription
{
	return @"iTunesLibrary.framework (provides fast read-only access to iTunes; requires iTunes v11.0 or newer and code signing)";
}

+ (BOOL)needsSigning
{
	return YES;
}

+ (BOOL)canGetArtworkCount
{
	// TODO investigate this
	return NO;
}

- (id)initWithTimer:(Timer *)t error:(NSError **)err
{
	self = [super init];
	if (self) {
		// technically this should be Nil, but the iTunesLibrary.framework documentation uses nil, so eh
		Class libraryClass = nil;

		self->timer = t;
		[self->timer retain];

		// initialize everything to be safe
		self->framework = nil;
		self->library = nil;
		*err = nil;

		[self->timer start:TimerLoad];
		self->framework = [[NSBundle alloc] initWithPath:frameworkPath];
		if (self->framework == nil) {
			*err = makeError(ErrBundleInitFailed, frameworkPath);
			goto out;
		}
		if ([self->framework loadAndReturnError:err] == NO) {
			// Apple's docs are self-contradictory as to whether err is guaranteed to be non-nil here.
			if (*err == nil)
				*err = makeError(ErrBundleLoadFailed, frameworkPath);
			else
				// NSErrors returned by Cocoa functions have to be unowned, even if they are CFErrorRef-based (thanks to mikeash in irc.freenode.net/#macdev, and possibly others too)
				[*err retain];
			goto out;
		}
		libraryClass = [self->framework classNamed:@"ITLibrary"];
		if (libraryClass == nil) {
			*err = makeError(ErrBundleClassNameFailed, @"ITLibrary", frameworkPath);
			goto out;
		}
		// TODO is this really collection...?
		self->library = (id<ourITLibrary>) [libraryClass alloc];
		self->library = [self->library initWithAPIVersion:@"1.0" error:err];
		if (self->library == nil) {
			// Apple's docs say that err *will* be filled.
			[*err retain];
			goto out;
		}
	out:
		[self->timer end];
	}
	return self;
}

- (void)dealloc
{
	if (self->library != nil)
		[self->library release];
	if (self->framework != nil) {
		// ignore any error; there's not much we can do if this fails anyway
		[self->framework unload];
		[self->framework release];
	}
	[self->timer release];
	[super dealloc];
}

- (NSArray *)collectTracks
{
	NSArray *tracks;
	NSMutableArray *items;

	[self->timer start:TimerCollect];
	tracks = [self->library allMediaItems];
	[self->timer end];

	[self->timer start:TimerConvert];
	items = [[NSMutableArray alloc] initWithCapacity:[tracks count]];
	// TODO this will cover all types of library entries, not just music
	for (id<ourITLibMediaItem> track in tracks) {
		Item *item;
		NSString *trackArtist, *albumArtist;

		trackArtist = [[track artist] name];
		albumArtist = [[track album] albumArtist];
		if ([[track album] isCompilation]) {
			trackArtist = compilationArtist;
			albumArtist = compilationArtist;
		}
		item = [[Item alloc] initWithYear:[track year]
			trackArtist:trackArtist
			album:[[track album] title]
			albumArtist:albumArtist
			lengthMilliseconds:[track totalTime]
			title:[track title]
			trackNumber:((NSInteger) [track trackNumber])
			discNumber:((NSInteger) [[track album] discNumber])
			artworkCount:0];
		[items addObject:item];
		[item release];		// and release the initial reference
	}
	[self->timer end];

	// don't release anything; we don't own references to them
	return items;
}

@end
