// 6 august 2017
#import "macgetalbums.h"

// TODO drop "length" and use "duration" everywhere?

static const struct {
	NSInteger year;
	NSString *artist;
	NSString *album;
} overrides[] = {
	// Each track on this album of previously unreleased material
	// is dated individually, so our "earliest year" algoritm doesn't
	// reflect the actual release date.
	{ 2011, @"Amy Winehouse", @"Lioness: Hidden Treasures" },

	// Some songs say 1982 (the year the film was released),
	// others say 1994 (the year the first disc was released);
	// neither of these might be accurate for each particular song.
	// Let's go with the year this particular release was released
	// (the 25th anniversary of the original film's release).
	{ 2007, @"Vangelis", @"Blade Runner Trilogy" },

	{ 0, nil, nil },
};

@implementation Track

- (id)initWithParams:(struct trackParams *)p length:(Duration *)l
{
	self = [super init];
	if (self) {
		int i;

		self->year = p->year;
		// use the album artist if there, track artist otherwise
		self->artist = p->albumArtist;
		// iTunesLibrary.framework uses nil; ScriptingBridge uses the empty string (I think; TODO)
		if (self->artist == nil || [self->artist isEqual:@""])
			self->artist = p->trackArtist;
		[self->artist retain];
		self->album = p->album;
		[self->album retain];
		self->length = l;
		[self->length retain];
		self->title = p->title;
		[self->title retain];
		self->trackNumber = p->trackNumber;
		self->trackCount = p->trackCount;
		self->discNumber = p->discNumber;
		self->discCount = p->discCount;
		self->artworkCount = p->artworkCount;

		// handle overrides
		for (i = 0; overrides[i].artist != nil; i++)
			if ([self->artist isEqual:overrides[i].artist] &&
				[self->album isEqual:overrides[i].album]) {
				self->year = overrides[i].year;
				break;
			}
	}
	return self;
}

- (id)initWithParams:(struct trackParams *)p lengthMilliseconds:(NSUInteger)ms
{
	Duration *l;

	l = [[Duration alloc] initWithMilliseconds:ms];
	self = [self initWithParams:p length:l];
	[l release];			// release the initial reference
	return self;
}

- (id)initWithParams:(struct trackParams *)p lengthSeconds:(double)sec
{
	Duration *l;

	l = [[Duration alloc] initWithSeconds:sec];
	self = [self initWithParams:p length:l];
	[l release];			// release the initial reference
	return self;
}

- (void)dealloc
{
	[self->title release];
	[self->length release];
	[self->album release];
	[self->artist release];
	[super dealloc];
}

- (void)combineWith:(Item *)i2
{
	// always use the earliest year
	if (self->year > i2->year)
		self->year = i2->year;
	// and combine the lengths
	[self->length add:i2->length];
}

- (NSInteger)year
{
	return self->year;
}

- (NSString *)artist
{
	return self->artist;
}

- (NSString *)album
{
	return self->album;
}

- (Duration *)length
{
	return self->length;
}

- (NSString *)title
{
	return self->title;
}

- (NSInteger)trackNumber
{
	return self->trackNumber;
}

- (NSInteger)trackCount
{
	return self->trackCount;
}

- (NSInteger)discNumber
{
	return self->discNumber;
}

- (NSInteger)discCount
{
	return self->discCount;
}

- (NSUInteger)artworkCount
{
	return self->artworkCount;
}

- (NSString *)formattedNumberTitleArtistAlbum
{
	NSString *base;
	NSString *ret;

	base = [[NSString alloc] initWithFormat:@"%@ (%@, %@)", self->title, self->artist, self->album];
	if (self->discNumber == 0)
		ret = [[NSString alloc] initWithFormat:@"   %02ld %@", (long) (self->trackNumber), base];
	else
		ret = [[NSString alloc] initWithFormat:@"% 2ld-%02ld %@", (long) (self->discNumber), (long) (self->trackNumber), base];
	[base release];
	return ret;
}

@end
