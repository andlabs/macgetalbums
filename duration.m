// 17 september 2017
#import "macgetalbums.h"

// ScriptingBridge reports durations as a double with seconds.
// iTunesLibrary.framework reports durations as a NSUInteger with milliseconds.
// This class manages the difference.

@implementation Duration

- (id)initWithMilliseconds:(NSUInteger)val
{
	self = [super init];
	if (self) {
		self->hasSeconds = NO;
		self->msec = val;
		self->sec = 0;
	}
	return self;
}

- (id)initWithSeconds:(double)val
{
	self = [super init];
	if (self) {
		self->hasSeconds = YES;
		self->msec = 0;
		self->sec = val;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	Duration *d;

	// thanks to mikeash in irc.freenode.net/#macdev for suggesting using [self class]
	d = [[[self class] allocWithZone:zone] initWithMilliseconds:0];
	if (d) {
		d->hasSeconds = self->hasSeconds;
		d->msec = self->msec;
		d->sec = self->sec;
	}
	return d;
}

- (void)add:(Duration *)d
{
	[self addMilliseconds:d->msec];
	if (d->hasSeconds)
		[self addSeconds:d->sec];
}

- (void)addMilliseconds:(NSUInteger)val
{
	self->msec += val;
}

- (void)addSeconds:(double)val
{
	self->hasSeconds = YES;
	self->sec += val;
}

- (NSUInteger)milliseconds
{
	NSUInteger ms;

	ms = self->msec;
	if (self->hasSeconds) {
		double dms;
		NSUInteger add;

		// round seconds up to the millisecond
		dms = self->sec * 1000;
		add = (NSUInteger) ceil(dms);
		ms += add;
	}
	return ms;
}

- (NSString *)stringWithOnlyMinutes:(BOOL)onlyMinutes
{
	NSUInteger ms;
	NSUInteger h, m, s;

	ms = [self milliseconds];
	s = ms / 1000;
	if (ms % 1000 != 0)		// round up to the second
		s++;
	m = s / 60;
	s = s % 60;
	if (onlyMinutes || m < 60)
		return [[NSString alloc] initWithFormat:@"%ju:%02ju",
			(uintmax_t) m, (uintmax_t) s];
	h = m / 60;
	m = m % 60;
	return [[NSString alloc] initWithFormat:@"%ju:%02ju:%02ju",
		(uintmax_t) h, (uintmax_t) m, (uintmax_t) s];
}

@end
