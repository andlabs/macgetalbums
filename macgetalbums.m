// 8 june 2017
#import <Cocoa/Cocoa.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import "iTunes.h"

// TODO consider MediaLibrary? (thanks mattstevens in irc.freenode.net #macdev)

// TODO Amy Winehouse's posthumous album is listed as 2002 when she was very much alive

BOOL verbose = NO;

static mach_timebase_info_data_t timebase;

// TODO consider https://developer.apple.com/documentation/foundation/nsprocessinfo/1414553-systemuptime?language=objc; it may not be as precise on the super-tight end, but it's in seconds and we won't need this class (thanks mikeash in irc.freenode.net #macdev)
@interface Timer : NSObject {
	uint64_t start, end;
}
- (void)start;
- (void)end;
- (uint64_t)nanoseconds;
- (double)seconds;
@end

@implementation Timer

+ (void)initialize
{
	// should not fail; see http://stackoverflow.com/questions/31450517/what-are-the-possible-return-values-for-mach-timebase-info
	// also true on 10.12 at least: https://opensource.apple.com/source/xnu/xnu-3789.1.32/libsyscall/wrappers/mach_timebase_info.c.auto.html + https://opensource.apple.com/source/xnu/xnu-3789.1.32/osfmk/kern/clock.c.auto.html
	mach_timebase_info(&timebase);
}

- (void)start
{
	self->start = mach_absolute_time();
}

- (void)end
{
	self->end = mach_absolute_time();
}

- (uint64_t)nanoseconds
{
	uint64_t duration;

	duration = self->end - self->start;
	return duration * timebase.numer / timebase.denom;
}

- (double)seconds
{
	uint64_t nsec;

	nsec = [self nanoseconds];
	return ((double) nsec) / ((double) NSEC_PER_SEC);
}

@end

@interface Track : NSObject
@property (strong) NSString *Album;
@property (strong) NSString *Artist;
@property NSInteger Year;
@end

@implementation Track

// see also https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html (thanks mattstevens in irc.freenode.net #macdev)
- (NSUInteger)hash
{
	return [self.Album hash] ^ [self.Artist hash];
}

- (BOOL)isEqual:(id)obj
{
	Track *b = (Track *) obj;

	return [self.Album isEqual:b.Album] &&
		[self.Artist isEqual:b.Artist];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%ld | %@ | %@",
		(long) (self.Year),
		self.Artist,
		self.Album];
}

@end

NSMutableSet *albums = nil;

@interface TrackEnumerator : NSObject {
	iTunesApplication *iTunes;
	SBElementArray *tracks;
	double seconds;
}
// TODO write dealloc function
- (void)collectTracks;
- (double)collectionDuration;
- (NSUInteger)nTracks;
- (Track *)track:(NSUInteger)i;
@end

@implementation TrackEnumerator

- (void)collectTracks
{
	Timer *timer;

	self->iTunes = (iTunesApplication *) [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

	timer = [Timer new];
	[timer start];
	self->tracks = [self->iTunes tracks];
	[timer end];
	self->seconds = [timer seconds];
	[timer release];
}

- (double)collectionDuration
{
	return self->seconds;
}

- (NSUInteger)nTracks
{
	return [self->tracks count];
}

- (Track *)track:(NSUInteger)i
{
	iTunesTrack *sbtrack;
	Track *track;

	sbtrack = (iTunesTrack *) [self->tracks objectAtIndex:i];
	track = [Track new];
	track.Album = [sbtrack album];
	track.Artist = [sbtrack albumArtist];
	if (track.Artist == nil) {
		fprintf(stderr, "TODO\n");
		exit(1);
	}
	if ([track.Artist isEqual:@""])
		track.Artist = [sbtrack artist];
	track.Year = [sbtrack year];
	// TODO release sbtrack?
	return track;
}

@end

int main(int argc, char *argv[])
{
	TrackEnumerator *e;
	Timer *timer;
	NSUInteger i, n;

	switch (argc) {
	case 1:
		break;
	case 2:
		if (strcmp(argv[1], "-v") == 0) {
			verbose = YES;
			break;
		}
		// fall through
	default:
		fprintf(stderr, "usage: %s [-v]\n", argv[0]);
		return 1;
	}

	e = [TrackEnumerator new];
	[e collectTracks];
	if (verbose)
		printf("time to issue script: %gs\n", [e collectionDuration]);

	albums = [NSMutableSet new];
	timer = [Timer new];
	[timer start];
	n = [e nTracks];
	if (verbose)
		// TODO with Scripting Bridge this is ~1e-5 seconds?! should we include the SBApplication constructor?
		printf("track count: %ld\n", (long) n);
	for (i = 0; i < n; i++) {
		Track *track;
		Track *existing;
		BOOL insert = YES;

		track = [e track:i];
		// only insert if either
		// - this is a new album, or
		// - the year on this track is earlier than the year on a prior track
		existing = (Track *) [albums member:track];
		if (existing != nil)
			if (track.Year >= existing.Year)
				insert = NO;
			else
				[albums removeObject:existing];
		if (insert)
			[albums addObject:track];
		[track release];			// and free our copy
	}
	[timer end];
	if (verbose)
		printf("time to process tracks: %gs\n", [timer seconds]);
	[timer release];

	if (verbose)
		printf("album count: %lu\n",
			(unsigned long) [albums count]);
	// TODO is tab safe to use?
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		Track *t = (Track *) obj;

		printf("%ld\t%s\t%s\n",
			(long) (t.Year),
			[t.Artist UTF8String],
			[t.Album UTF8String]);
	}];

	// TODO clean up?
	return 0;
}
