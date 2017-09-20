// 6 august 2017
#import "macgetalbums.h"

// TODO drop "length" and use "duration" everywhere?
// TODO and rename this to Track?

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

@implementation Item

- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa length:(Duration *)l
{
	self = [super init];
	if (self) {
		int i;

		self->year = y;
		// use the album artist if there, track artist otherwise
		self->artist = aa;
		// iTunesLibrary.framework does this
		// we do this too in -copyWithZone: below
		if (self->artist == nil)
			self->artist = @"";
		if ([self->artist isEqual:@""])
			self->artist = ta;
		[self->artist retain];
		self->album = a;
		[self->album retain];
		self->length = l;
		[self->length retain];

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

- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthMilliseconds:(NSUInteger)ms
{
	Duration *l;

	l = [[Duration alloc] initWithMilliseconds:ms];
	self = [self initWithYear:y
		trackArtist:ta
		album:a
		albumArtist:aa
		length:l];
	[l release];			// release the initial reference
	return self;
}

- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthSeconds:(double)sec
{
	Duration *l;

	l = [[Duration alloc] initWithSeconds:sec];
	self = [self initWithYear:y
		trackArtist:ta
		album:a
		albumArtist:aa
		length:l];
	[l release];			// release the initial reference
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	Item *i;
	Duration *l2;

	l2 = [self->length copy];
	i = [[[self class] allocWithZone:zone] initWithYear:self->year
		trackArtist:self->artist
		album:self->album
		albumArtist:nil		// see above
		length:l2];
	[l2 release];			// release the initial reference
	return i;
}

- (void)dealloc
{
	[self->artist release];
	[self->album release];
	[self->length release];
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

// see also https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html (thanks mattstevens in irc.freenode.net #macdev)
- (NSUInteger)hash
{
	return [self->artist hash] ^ [self->album hash];
}

- (BOOL)isEqual:(id)obj
{
	Item *b = (Item *) obj;

	return [self->artist isEqual:b->artist] &&
		[self->album isEqual:b->album];
}

// TODO is this needed?
- (NSString *)description
{
	return [NSString stringWithFormat:@"%ld | %@ | %@ | %@",
		(long) (self->year),
		self->artist,
		self->album,
		self->length];
}

@end
