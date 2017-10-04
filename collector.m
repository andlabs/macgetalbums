// 23 september 2017
#import "macgetalbums.h"

static const struct {
	const char *name;
	// because @selector() is not a compile-time constant :|
	NSString *sel;
	NSString *reverseSel;
} sortModes[] = {
	{ "artist", @"compareForSortByArtist:", @"compareForReverseSortByArtist:" },
	{ "year", @"compareForSortByYear:", @"compareForReverseSortByYear:" },
	{ "length", @"compareForSortByLength:", @"compareForReverseSortByLength:" },
	{ "none", nil, nil },
	{ NULL, nil, nil },
};

@implementation Collection

- (id)initWithTracks:(NSArray *)t albums:(NSSet *)a totalDuration:(Duration *)d
{
	self = [super init];
	if (self) {
		self->tracks = t;
		[self->tracks retain];
		self->albums = a;
		[self->albums retain];
		self->totalDuration = d;
		[self->totalDuration retain];
	}
	return self;
}

- (void)dealloc
{
	[self->totalDuration release];
	[self->albums release];
	[self->tracks release];
	[super dealloc];
}

- (NSArray *)tracks
{
	return self->tracks;
}

- (NSSet *)albums
{
	return self->albums;
}

- (Duration *)totalDuration
{
	return self->totalDuration;
}

+ (NSString *)copySortModeList
{
	NSMutableString *ret;
	int i;

	i = 0;
	ret = [[NSMutableString alloc] initWithUTF8String:sortModes[i].name];
	for (i++; sortModes[i].name != NULL; i++)
		[ret appendFormat:@", %s", sortModes[i].name];
	return ret;
}

+ (BOOL)isValidSortMode:(const char *)mode
{
	int i;

	for (i = 0; sortModes[i].name != NULL; i++)
		if (strcmp(sortModes[i].name, mode) == 0)
			return YES;
	return NO;
}

- (NSArray *)copySortedAlbums:(const char *)sortMode reverseSort:(BOOL)reverseSort
{
	NSArray *array;
	NSString *sel;
	int i;

	for (i = 0; sortModes[i].name != NULL; i++)
		if (strcmp(sortModes[i].name, sortMode) == 0)
			break;
	if (sortModes[i].name == NULL)
		[NSException raise:NSInvalidArgumentException
			// TODO manage memory properly for NSStringFromClass()
			format:@"unknown sort mode %s given to -[%@ copySortedAlbums:]", sortMode, NSStringFromClass([self class])];

	array = [self->albums allObjects];
	sel = sortModes[i].sel;
	if (reverseSort)
		sel = sortModes[i].reverseSel;
	if (sel != nil)
		array = [array sortedArrayUsingSelector:NSSelectorFromString(sel)];
	else if (reverseSort)
		// special case for when reversing "none"
		// TODO properly manage memory for the enumerator
		array = [[array reverseObjectEnumerator] allObjects];
	[array retain];
	return array;
}

@end

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
