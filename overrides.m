// 6 august 2017
#import "macgetalbums.h"

static const struct {
	NSString *album;
	NSString *artist;
	NSInteger year;
} overrides[] = {
	// Each track on this album of previously unreleased material
	// is dated individually, so our "earliest year" algoritm doesn't
	// reflect the actual release date.
	{ @"Lioness: Hidden Treasures", @"Amy Winehouse", 2011 },

	{ nil, nil, 0 },
};

// TODO find a better name?
// TODO rearrange parameters
NSInteger handleOverrides(NSString *album, NSString *artist, NSInteger year)
{
	int i;

	for (i = 0; overrides[i].album != nil; i++)
		if ([album isEqual:overrides[i].album] &&
			[artist isEqual:overrides[i].artist])
			return overrides[i].year;
	return year;
}
