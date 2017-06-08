// 8 june 2017
#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import <string.h>
#import <mach/mach.h>
#import <mach/mach_time.h>

// TODO consider Scripting Bridge, then MediaLibrary?

BOOL verbose = NO;

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
	uint64_t duration;
}
// TODO write dealloc function
- (NSDictionary *)collectTracks;
- (double)collectionDuration;
- (NSInteger)nTracks;
- (NSDictionary *)track:(NSInteger)i;
@end

@implementation TrackEnumerator

- (NSDictionary *)collectTracks
{
	NSString *source;
	NSDictionary *err;
	uint64_t start, end;

	source = [NSString stringWithUTF8String:scriptSource];
	self->script = [[NSAppleScript alloc] initWithSource:source];

	start = mach_absolute_time();
	self->tracks = [self->script executeAndReturnError:&err];
	end = mach_absolute_time();
	self->duration = end - start;
	if (self->tracks == nil)
		return err;
	return nil;
}

- (double)collectionDuration
{
	mach_timebase_info_data_t mt;
	uint64_t dur;
	double sec;

	// should not fail; see http://stackoverflow.com/questions/31450517/what-are-the-possible-return-values-for-mach-timebase-info
	// also true on 10.12 at least: https://opensource.apple.com/source/xnu/xnu-3789.1.32/libsyscall/wrappers/mach_timebase_info.c.auto.html + https://opensource.apple.com/source/xnu/xnu-3789.1.32/osfmk/kern/clock.c.auto.html
	mach_timebase_info(&mt);
	dur = self->duration;
	dur = dur * mt.numer / mt.denom;
	sec = ((double) dur) / ((double) NSEC_PER_SEC);
	return sec;
}

- (NSInteger)nTracks
{
	return [self->tracks numberOfItems];
}

// see also http://www.cocoabuilder.com/archive/cocoa/281785-extract-keys-values-from-usrf-record-type-nsappleeventdescriptor.html
- (NSDictionary *)track:(NSInteger)i
{
	NSAppleEventDescriptor *desc;
	NSMutableDictionary *dict;
	NSInteger n;

	// TODO free desc afterward?
	desc = [self->tracks descriptorAtIndex:(i + 1)];
	// TODO figure out why this is needed; free desc afterward?
	desc = [desc descriptorAtIndex:1];
	dict = [NSMutableDictionary new];
	n = [desc numberOfItems];
	// note: 1-based
	for (i = 1; i <= n; i += 2) {
		NSAppleEventDescriptor *key, *value;
		NSString *keystr;
		id valueobj;

		key = [desc descriptorAtIndex:i];
		value = [desc descriptorAtIndex:(i + 1)];
		keystr = [key stringValue];
		if ([keystr isEqualToString:@"year"]) {
			SInt32 v;

			v = [value int32Value];
			valueobj = [NSNumber numberWithInteger:((NSInteger) v)];
			// TODO do not free valueobj
		} else
			valueobj = [value stringValue];
		[dict setObject:valueobj forKey:keystr];
		// TODO release key, value, keystr, or valueobj?
	}
	return dict;
}

@end

int main(int argc, char *argv[])
{
	TrackEnumerator *e;
	NSDictionary *err;
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

	n = [e nTracks];
	if (verbose)
		printf("track count: %ld\n", (long) n);
	for (i = 0; i < n; i++) {
		NSDictionary *track;

		track = [e track:i];
		printf("%s\n", [[track description] UTF8String]);
		[track release];// TODO
	}

	// TODO clean up?
	return 0;
}
