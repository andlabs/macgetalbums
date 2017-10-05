// 23 september 2017
#import "macgetalbums.h"

NSString *const CollectionParamsIncludeArtworkKey = @"CollectionParamsIncludeArtworkKey";

static BOOL paramsIncludeArtwork(NSDictionary *params)
{
	NSNumber *n;

	n = (NSNumber *) [params objectForKey:CollectionParamsIncludeArtworkKey];
	if (n == nil)
		return NO;
	return [n boolValue];
}

NSString *const CollectionParamsExcludeAlbumsRegexpKey = @"CollectionParamsExcludeAlbumsRegexpKey";

static Regexp *paramsExcludeAlbumsRegexp(NSDictionary *p)
{
	return (Regexp *) [p objectForKey:CollectionParamsExcludeAlbumsRegexpKey];
}

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

- (id)initWithParams:(NSDictionary *)p trackCount:(NSUInteger)trackCount
{
	self = [super init];
	if (self) {
		self->params = p;
		[self->params retain];
		self->tracks = [[NSMutableArray alloc] initWithCapacity:trackCount];
		self->albums = [[NSMutableSet alloc] initWithCapacity:trackCount];
		self->totalDuration = [[Duration alloc] initWithMilliseconds:0];
	}
	return self;
}

- (void)dealloc
{
	[self->totalDuration release];
	[self->albums release];
	[self->tracks release];
	[self->params release];
	[super dealloc];
}

- (void)addTrack:(Track *)t withFirstTrack:(id<NSObject>)firstTrack isRealFirstTrackFunc:(IsRealFirstTrackFunc)f
{
	Regexp *r;
	Album *a;

	// do we exclude this album?
	r = paramsExcludeAlbumsRegexp(self->params);
	if (r != nil && [r matches:[t album]])
		return;

	// okay, we're good to add the track
	[self->tracks addObject:t];
	a = albumInSet(self->albums, [t artist], [t album]);
	[a addTrack:t];
	if ([a firstTrack] == nil || (*f)(firstTrack, a))
		[a setFirstTrack:firstTrack];
	[self->totalDuration add:[t length]];
}

- (void)addArtworksAndReleaseFirstTracks:(AddArtworkFunc)f
{
	BOOL withArtwork;

	withArtwork = paramsIncludeArtwork(self->params);
	for (Album *a in self->albums) {
		if ([a firstTrack] == nil)
			continue;
		if (withArtwork)
			(*f)(a);
		[a setFirstTrack:nil];
	}
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
