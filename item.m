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

@implementation Item

- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa length:(Duration *)l
{
	self = [super init];
	if (self) {
		int i;

		self->year = y;
		// use the album artist if there, track artist otherwise
		self->artist = aa;
		if (self->artist == nil) {
			fprintf(stderr, "TODO\n");
			exit(1);
		}
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

- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthMilliseconds:(NSUinteger)ms
{
	Duration *l;

	l = [[Duration alloc] initWithMilliseconds:ms];
	self = [self initWithYear:y
		trackArtist:ta
		album:a
		albumArtist:aa
		length:l];
	[l release];
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
	[l release];
	return self;
}

- (void)dealloc
{
	[self->artist release];
	[self->album release];
	[self->length release];
	[super dealloc];
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
