// 6 august 2017
#import "macgetalbums.h"

// TODO drop "length" and use "duration" everywhere?

NSString *const compilationArtist = @"(compilation)";

@implementation Album

- (id)initWithYear:(NSInteger)year artist:(NSString *)aa album:(NSString *)a
{
	self = [super init];
	if (self) {
		int i;

		self->year = y;
		// use the album artist if there, track artist otherwise
		self->artist = aa;
		[self->artist retain];
		self->album = a;
		[self->album retain];
		self->length = [[Duration alloc] initWithMilliseconds:0];
		self->trackCount = 0;
		self->discCount = 0;
		self->firstTrack = nil;
		self->firstArtwork = nil;
	}
	return self;
}

- (void)dealloc
{
	if (self->firstArtwork != nil)
		[self->firstArtwork release];
	if (self->firstTrack != nil)
		[self->firstTrack release];
	[self->length release];
	[self->album release];
	[self->artist release];
	[super dealloc];
}

- (void)addTrack:(Track *)t
{
	// always use the earliest year
	if (self->year > [t year])
		self->year = [t year];
	// and combine the lengths
	[self->length add:[t length]];
	// TODO use [t trackCount], or remove it?
	self->trackCount++;
	if (self->discCount < [t discCount])
		self->discCount = [t discCount];
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

- (NSInteger)trackCount
{
	return self->trackCount;
}

- (NSInteger)discCount
{
	return self->discCount;
}

- (id<NSObject>)firstTrack
{
	return self->firstTrack;
}

- (void)setFirstTrack:(id<NSObject>)ft
{
	if (self->firstTrack != nil)
		[self->firstTrack release];
	self->firstTrack = ft;
	if (self->firstTrack != nil)
		[self->firstTrack retain];
}

- (NSImage *)firstArtwork
{
	return self->firstArtwork;
}

- (void)setFirstArtwork:(NSImage *)a
{
	if (self->firstArtwork != nil)
		[self->firstArtwork release];
	self->firstArtwork = a;
	if (self->firstArtwork != nil)
		[self->firstArtwork retain];
}

// note that these two operate like prepare.sh
- (NSComparisonResult)compareForSortByYear:(Album *)b
{
	NSComparisonResult r;

	if (self->year < b->year)
		return NSOrderedAscending;
	if (self->year > b->year)
		return NSOrderedDescending;
	r = [self->artist compare:b->artist];
	if (r != NSOrderedSame)
		return r;
	return [self->album compare:b->album];
}

- (NSComparisonResult)compareForSortByLength:(Album *)b
{
	NSComparisonResult r;

	r = [self->length compare:b->length];
	if (r != NSOrderedSame)
		return r;
	return [self compareForSortByYear:b];
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

@end
