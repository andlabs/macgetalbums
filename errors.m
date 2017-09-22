// 21 september 2017
#import "macgetalbums.h"

NSString *const ErrDomain = @"com.andlabs.macgetalbums.ErrorDomain";

// you own the NSError here
NSError *makeError(NSInteger errcode, ...)
{
	va_list ap;
	NSString *desc;
	NSDictionary *userInfo;
	id keys[2];
	id values[2];
	NSUInteger n;
	NSError *err;

	keys[0] = nil;
	values[0] = nil;
	keys[1] = nil;
	values[1] = nil;
	n = 0;

	va_start(ap, errcode);
	desc = [NSString alloc];
	switch (errcode) {
	case ErrSigningNeeded:
		desc = [desc initWithFormat:@"collector %s needs signing and we aren't signed; skipping", va_arg(ap, const char *)];
		break;
	case ErrCannotCollectArtwork:
		desc = [desc initWithFormat:@"collector %s can't be used to get album artwork counts; skipping", va_arg(ap, const char *)];
		break;
	default:
		desc = [desc initWithFormat:@"(unknown error code %ld)", (long) errcode];
	}
	va_end(ap);
	keys[0] = NSLocalizedDescriptionKey;
	values[0] = desc;
	n++;

	userInfo = [[NSDictionary alloc] initWithObjects:values
		forKeys:keys
		count:n];
	[desc release];
	err = [[NSError alloc] initWithDomain:ErrDomain
		code:errcode
		userInfo:userInfo];
	[userInfo release];
	return err;
}
