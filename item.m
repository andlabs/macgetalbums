// 6 august 2017
#import "macgetalbums.h"

static const struct {
	NSInteger year;
	NSString *artist;
	NSString *album;
} overrides[] = {
	// Each track on this album of previously unreleased material
	// is dated individually, so our "earliest year" algoritm doesn't
	// reflect the actual release date.
	{ 2011, @"Amy Winehouse", @"Lioness: Hidden Treasures" },

	{ 0, nil, nil },
};

@implementation Item

// see also https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html (thanks mattstevens in irc.freenode.net #macdev)
- (NSUInteger)hash
{
	return [self.Artist hash] ^ [self.Album hash];
}

- (BOOL)isEqual:(id)obj
{
	Item *b = (Item *) obj;

	return [self.Artist isEqual:b.Artist] &&
		[self.Album isEqual:b.Album];
}

- (NSString *)lengthString
{
	uintmax_t len;
	uintmax_t hr, min, sec;

	len = (uintmax_t) ceil(self.Length);		// round up to the nearest second
	sec = len % 60;
	min = len / 60;
	if (min < 60)
		return [NSString stringWithFormat:@"%ju:%02ju",
			min, sec];
	hr = min / 60;
	min = min % 60;
	return [NSString stringWithFormat:@"%ju:%02ju:%02ju",
		hr, min, sec];
}

// TODO is this needed?
- (NSString *)description
{
	return [NSString stringWithFormat:@"%ld | %@ | %@ | %@",
		(long) (self.Year),
		self.Artist,
		self.Album,
		[self lengthString]];
}

- (void)handleOverrides
{
	int i;

	for (i = 0; overrides[i].artist != nil; i++)
		if ([self.Artist isEqual:overrides[i].artist] &&
			[self.Album isEqual:overrides[i].album]) {
			self.Year = overrides[i].year;
			return;
		}
}

@end
