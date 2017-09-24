// 23 september 2017
#import "macgetalbums.h"

NSArray *defaultCollectorsArray(void)
{
	NSArray *arr;

	arr = [NSArray alloc];
	return [arr initWithObjects:@"iTunesLibraryCollector",
		@"ScriptingBridgeCollector",
		nil];
}

NSArray *singleCollectorArray(const char *what)
{
	NSString *s;
	NSArray *arr;
	BOOL found;

	s = [[NSString alloc] initWithUTF8String:what];

	found = NO;
	arr = defaultCollectorsArray();
	for (NSString *t in arr)
		if ([s isEqual:t]) {
			found = YES;
			break;
		}
	[arr release];
	arr = nil;

	if (found)
		arr = [[NSArray alloc] initWithObjects:s, nil];
	[s release];
	return arr;
}

void foreachCollector(NSArray *collectors, foreachCollectorFunc f, void *data)
{
	Class<Collector> class;
	BOOL stop;

	for (NSString *c in collectors) {
		class = NSClassFromString(c);
		stop = (*f)(c, class, data);
		if (stop)
			break;
	}
}
