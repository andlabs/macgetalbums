// 7 august 2017
#import "macgetalbums.h"

static mach_timebase_info_data_t timebase;

// TODO consider https://developer.apple.com/documentation/foundation/nsprocessinfo/1414553-systemuptime?language=objc; it may not be as precise on the super-tight end, but it's in seconds and we won't need this class (thanks mikeash in irc.freenode.net #macdev)

@implementation Timer

+ (void)initialize
{
	// should not fail; see http://stackoverflow.com/questions/31450517/what-are-the-possible-return-values-for-mach-timebase-info
	// also true on 10.12 at least: https://opensource.apple.com/source/xnu/xnu-3789.1.32/libsyscall/wrappers/mach_timebase_info.c.auto.html + https://opensource.apple.com/source/xnu/xnu-3789.1.32/osfmk/kern/clock.c.auto.html
	mach_timebase_info(&timebase);
}

- (id)init
{
	self = [super init];
	if (self) {
		self->cur = 0;
		memset(self->starts, 0, nTimers * sizeof (uint64_t));
		memset(self->ends, 0, nTimers * sizeof (uint64_t));
	}
	return self;
}

- (void)start:(int)t
{
	if (self->cur != 0)
		[self end];
	self->cur = t;
	self->starts[self->cur] = mach_absolute_time();
}

- (void)end
{
	self->ends[self->cur] = mach_absolute_time();
	self->cur = 0;
}

- (uint64_t)nanoseconds:(int)t
{
	uint64_t duration;

	if (t == self->cur)
		[self end];
	duration = self->ends[t] - self->starts[t];
	return duration * timebase.numer / timebase.denom;
}

- (double)seconds:(int)t
{
	uint64_t nsec;

	nsec = [self nanoseconds:t];
	return ((double) nsec) / ((double) NSEC_PER_SEC);
}

@end
