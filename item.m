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

// TODO find a better name?
NSInteger handleOverrides(NSInteger year, NSString *artist, NSString *album)
{
	int i;

	for (i = 0; overrides[i].artist != nil; i++)
		if ([artist isEqual:overrides[i].artist] &&
			[album isEqual:overrides[i].album])
			return overrides[i].year;
	return year;
}
