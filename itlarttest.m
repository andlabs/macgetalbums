// 24 september 2017
#import <Cocoa/Cocoa.h>
#import <iTunesLibrary/iTunesLibrary.h>

// build:
// clang -o itlarttest itlarttest.m -fobjc-arc -F/Library/Frameworks -framework Foundation -framework AppKit -framework iTunesLibrary -Wall -Wextra -pedantic -Wno-unused-parameter --std=c99 && codesign -s - itlarttest

void dumpITLibArtwork(ITLibArtwork *a)
{
	NSImage *img;

	NSLog(@"format %lu", (unsigned long) [a imageDataFormat]);
	NSLog(@"image data: %lu bytes; first 16:", (unsigned long) [[a imageData] length]);
	NSLog(@"%@", [[a imageData] subdataWithRange:NSMakeRange(0, 16)]);
	img = [a image];
	NSLog(@"image: %@", img);
	img = [[NSImage alloc] initWithData:[a imageData]];
	NSLog(@"manual: %@", img);
	[img recache];
	NSLog(@"after recache: %@", img);
}

int main(int argc, char *argv[])
{
	NSString *title, *artist, *album;
	ITLibrary *library;
	ITLibMediaItem *track;
	NSError *err;

	title = [NSString stringWithUTF8String:argv[1]];
	artist = [NSString stringWithUTF8String:argv[2]];
	album = [NSString stringWithUTF8String:argv[3]];

	err = nil;
	library = [[ITLibrary alloc] initWithAPIVersion:@"1.0" error:&err];
	if (library == nil) {
		NSLog(@"error loading iTunesLibrary.dylib: %@", err);
		return 1;
	}

	for (track in [library allMediaItems])
		if ([title isEqual:[track title]] &&
			[artist isEqual:[[track artist] name]] &&
			[album isEqual:[[track album] title]])
			break;
	if (track == nil) {
		NSLog(@"song not found");
		return 1;
	}

	NSLog(@"has: %d", [track hasArtworkAvailable]);
	NSLog(@"artwork: %@", [track artwork]);
	dumpITLibArtwork([track artwork]);
	NSLog(@"property: %@", [track valueForProperty:ITLibMediaItemPropertyArtwork]);
	dumpITLibArtwork([track valueForProperty:ITLibMediaItemPropertyArtwork]);

	return 0;
}
