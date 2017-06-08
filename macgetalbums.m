// 8 june 2017
#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <mach/mach.h>
#import <mach/mach_time.h>

// TODO consider Scripting Bridge, then MediaLibrary? (thanks mattstevens in irc.freenode.net #macdev)

BOOL verbose = NO;

static mach_timebase_info_data_t timebase;

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
@property SInt32 Year;
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
	return [NSString stringWithFormat:@"%d | %@ | %@",
		(int) (self.Year),
		self.Artist,
		self.Album];
}

@end

NSMutableSet *albums = nil;

const char *scriptSource =
	"tell application \"iTunes\"\n"
	"	set allItems to {}\n"
	"	repeat with t in tracks\n"
	"		set yr to year of t\n"
	"		set ar to album artist of t\n"
	"		if ar is \"\" then\n"
	"			set ar to artist of t\n"
	"		end if\n"
	"		set al to album of t\n"
	"		set newItem to {|year|:yr, |artist|:ar, |album|:al}\n"
	"		set end of allItems to newItem\n"
	"	end repeat\n"
	"	allItems\n"
	"end tell\n";

@interface TrackEnumerator : NSObject {
	NSAppleScript *script;
	NSAppleEventDescriptor *tracks;
	double seconds;
}
// TODO write dealloc function
- (NSDictionary *)collectTracks;
- (double)collectionDuration;
- (NSInteger)nTracks;
- (Track *)track:(NSInteger)i;
@end

@implementation TrackEnumerator

- (NSDictionary *)collectTracks
{
	NSString *source;
	NSDictionary *err;
	Timer *timer;

	source = [NSString stringWithUTF8String:scriptSource];
	self->script = [[NSAppleScript alloc] initWithSource:source];

	timer = [Timer new];
	[timer start];
	self->tracks = [self->script executeAndReturnError:&err];
	[timer end];
	self->seconds = [timer seconds];
	[timer release];
	if (self->tracks == nil)
		return err;
	return nil;
}

- (double)collectionDuration
{
	return self->seconds;
}

- (NSInteger)nTracks
{
	return [self->tracks numberOfItems];
}

// see also http://www.cocoabuilder.com/archive/cocoa/281785-extract-keys-values-from-usrf-record-type-nsappleeventdescriptor.html
- (Track *)track:(NSInteger)i
{
	NSAppleEventDescriptor *desc;
	Track *track;
	NSInteger n;

	// TODO free desc afterward?
	desc = [self->tracks descriptorAtIndex:(i + 1)];
	// TODO figure out why this is needed; free desc afterward?
	desc = [desc descriptorAtIndex:1];
	track = [Track new];
	n = [desc numberOfItems];
	// note: 1-based
	for (i = 1; i <= n; i += 2) {
		NSAppleEventDescriptor *key, *value;
		NSString *keystr;

		key = [desc descriptorAtIndex:i];
		value = [desc descriptorAtIndex:(i + 1)];
		keystr = [key stringValue];
		if ([keystr isEqual:@"year"])
			track.Year = [value int32Value];
		else if ([keystr isEqual:@"album"])
			track.Album = [value stringValue];
		else if ([keystr isEqual:@"artist"])
			track.Artist = [value stringValue];
		else {
			fprintf(stderr, "unknown record key %s\n", [keystr UTF8String]);
			exit(1);
		}
		// TODO release key, value, keystr, or valueobj?
	}
	return track;
}

@end

int main(int argc, char *argv[])
{
	TrackEnumerator *e;
	NSDictionary *err;
	Timer *timer;
	NSInteger i, n;

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
	err = [e collectTracks];
	if (err != nil) {
		fprintf(stderr, "error: script execution failed: %s\n",
			[[err description] UTF8String]);
		return 1;
	}
	if (verbose)
		printf("time to issue script: %gs\n", [e collectionDuration]);

	albums = [NSMutableSet new];
	timer = [Timer new];
	[timer start];
	n = [e nTracks];
	if (verbose)
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

	// TODO
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		printf("%s\n", [[obj description] UTF8String]);
	}];

	// TODO clean up?
	return 0;
}
