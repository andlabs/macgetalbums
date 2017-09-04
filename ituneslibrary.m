// 3 september 2017
#import <Foundation/Foundation.h>
#import <iTunesLibrary/iTunesLibrary.h>

int main(void)
{
	ITLibrary *library;
	NSError *err;

	library = [[ITLibrary alloc] initWithAPIVersion:@"1.0" error:&err];
	if (library == nil) {
		NSLog(@"error initializing library: %@", err);
		return 1;
	}
	NSLog(@"count: %lu", (unsigned long) [[library allMediaItems] count]);
	// TODO does this only cover music or not? compare to the ScriptingBridge code
	for (ITLibMediaItem *track in [library allMediaItems]) {
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
	return 0;
}
