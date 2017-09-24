// 23 september 2017
#import "macgetalbums.h"

void xvfprintf(FILE *f, NSString *fmt, va_list ap)
{
	NSString *s;

	s = [[NSString alloc] initWithFormat:fmt arguments:ap];
	fprintf(f, "%s", [s UTF8String]);
	[s release];
}

void xfprintf(FILE *f, NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	xvfprintf(f, fmt, ap);
	va_end(ap);
}

void xprintf(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	xvfprintf(stdout, fmt, ap);
	va_end(ap);
}

void xstderrprintf(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	xvfprintf(stdout, fmt, ap);
	va_end(ap);
}

BOOL suppressLogs = YES;

void xlogv(NSString *fmt, va_list ap)
{
	if (suppressLogs)
		return;
	NSLogv(fmt, ap);
}

void xlog(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	xlogv(fmt, ap);
	va_end(ap);
}

void xlogtimer(NSString *msg, Timer *timer, int which)
{
	NSString *ts;

	ts = [timer stringFor:which];
	xlog(@"time to %@: %@", msg, ts);
	[ts release];
}
