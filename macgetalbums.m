// 8 june 2017
#import "macgetalbums.h"

// TODO consider MediaLibrary? (thanks mattstevens in irc.freenode.net #macdev)

// TODO rename to main.m?

// TODO make getopt()-based
BOOL verbose = NO;

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
- (Item *)track:(NSUInteger)i;
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

// TODO fix up the names
- (Item *)track:(NSUInteger)i
{
	iTunesTrack *sbtrack;
	Item *track;

	sbtrack = (iTunesTrack *) [self->tracks objectAtIndex:i];
	track = [Item new];
	track.Year = [sbtrack year];
	track.Artist = [sbtrack albumArtist];
	if (track.Artist == nil) {
		fprintf(stderr, "TODO\n");
		exit(1);
	}
	if ([track.Artist isEqual:@""])
		track.Artist = [sbtrack artist];
	track.Album = [sbtrack album];
	[track handleOverrides];
	track.Length = [sbtrack duration];
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
		Item *track;
		Item *existing;
		BOOL insert = YES;

		track = [e track:i];
		// only insert if either
		// - this is a new album, or
		// - the year on this track is earlier than the year on a prior track
		existing = (Item *) [albums member:track];
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
		Item *t = (Item *) obj;

		printf("%ld\t%s\t%s\n",
			(long) (t.Year),
			[t.Artist UTF8String],
			[t.Album UTF8String]);
	}];

	// TODO clean up?
	return 0;
}
