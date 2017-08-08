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

- (void)start
{
	self->start = mach_absolute_time();
}

- (void)end
{
	self->end = mach_absolute_time();
}

- (uint64_t)nanoseconds
{
	uint64_t duration;

	duration = self->end - self->start;
	return duration * timebase.numer / timebase.denom;
}

- (double)seconds
{
	uint64_t nsec;

	nsec = [self nanoseconds];
	return ((double) nsec) / ((double) NSEC_PER_SEC);
}

@end
