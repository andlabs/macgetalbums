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

// TODO should this be autoreleased?
#define genericError() [[NSError alloc] initWithDomain:NSMachErrorDomain code:KERN_FAILURE userInfo:nil]

// TODO figure out how far back we can have ivars in @implementation
@implementation iTunesLibraryCollector {
	Timer *timer;
	NSBundle *framework;
	id<ourITLibrary> library;
}

+ (NSString *)collectorName
{
	return @"iTunesLibrary Framework";
}

+ (BOOL)needsSigning
{
	return YES;
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
		self->framework = [[NSBundle alloc] initWithPath:@"/Library/Frameworks/iTunesLibrary.framework"];
		if (self->framework == nil) {
			*err = genericError();
			goto out;
		}
		if ([self->framework loadAndReturnError:err] == NO) {
			// Apple's docs are self-contradictory as to whether err is non-nil here.
			if (*err == nil)
				*err = genericError();
			goto out;
		}
		libraryClass = [self->framework classNamed:@"ITLibrary"];
		if (libraryClass == nil) {
			// TODO find a class not found error?
			*err = genericError();
			goto out;
		}
		// TODO is this really collection...?
		self->library = (id<ourITLibrary>) [libraryClass alloc];
		self->library = [self->library initWithAPIVersion:@"1.0" error:err];
		if (self->library == nil)
			// Apple's docs say that err *will* be filled.
			goto out;
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

// TODO make this an instance stuff
- (NSArray *)collectTracks
{
	NSArray *tracks;
	NSMutableArray *items;

	[self->timer start:TimerCollect];
	tracks = [self->library allMediaItems];
	[self->timer end];

	// TODO add a TimerConvert
	items = [[NSMutableArray alloc] initWithCapacity:[tracks count]];
	// TODO does this only cover music or not? compare to the ScriptingBridge code
	for (id<ourITLibMediaItem> track in tracks) {
		Item *item;

		item = [[Item alloc] initWithYear:[track year]
			trackArtist:[[track artist] name]
			album:[[track album] title]
			albumArtist:[[track album] albumArtist]
			lengthMilliseconds:[track totalTime]];
		[items addObject:item];
		[item release];		// and release the initial reference
	}

	// TODO is this release correct?
	[tracks release];
	return items;
}

@end
