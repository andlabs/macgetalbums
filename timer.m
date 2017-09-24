// 7 august 2017
#import "macgetalbums.h"

static mach_timebase_info_data_t timebase;

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

- (NSString *)stringFor:(int)t
{
	uint64_t nsec;
	double d;
	uint64_t hours, minutes;
	NSMutableString *ret;
	NSString *fmt;

	nsec = [self nanoseconds:t];
	if (nsec == 0)
		return [@"0s" copy];
	if (nsec < 1000) {
		fmt = [[NSString alloc] initWithFormat:@"%%%sns", PRIu64];
		ret = [[NSMutableString alloc] initWithFormat:fmt, nsec];
		[fmt release];
		return ret;
	}
	if (nsec < 1000000) {
		d = ((double) nsec) / 1000;
		return [[NSString alloc] initWithFormat:@"%.3gus", d];
	}
	if (nsec < 1000000000) {
		d = ((double) nsec) / 1000000;
		return [[NSString alloc] initWithFormat:@"%.6gms", d];
	}
	hours = nsec / 3600000000000;
	nsec %= 3600000000000;
	ret = [NSMutableString new];
	if (hours != 0) {
		fmt = [[NSString alloc] initWithFormat:@"%%%sh", PRIu64];
		[ret appendFormat:fmt, hours];
		[fmt release];
	}
	minutes = nsec / 60000000000;
	nsec %= 60000000000;
	if (minutes != 0) {
		fmt = [[NSString alloc] initWithFormat:@"%%%sm", PRIu64];
		[ret appendFormat:fmt, minutes];
		[fmt release];
	}
	d = ((double) nsec) / 1000000000;
	[ret appendFormat:@"%.9gs", d];
	return ret;
}

@end
