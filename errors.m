// 21 september 2017
#import "macgetalbums.h"

NSString *const ErrDomain = @"com.andlabs.macgetalbums.ErrorDomain";

// you own the NSError here
NSError *makeError(NSInteger errcode, ...)
{
	va_list ap;
	NSString *desc, *a1, *a2;
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
	case ErrBundleInitFailed:
		desc = [desc initWithFormat:@"initializing NSBundle at %@ failed for some unknown reason", va_arg(ap, NSString *)];
		break;
	case ErrBundleLoadFailed:
		desc = [desc initWithFormat:@"loading NSBundle at %@ failed for some unknown reason", va_arg(ap, NSString *)];
		break;
	case ErrBundleClassNameFailed:
		a1 = va_arg(ap, NSString *);
		a2 = va_arg(ap, NSString *);
		desc = [desc initWithFormat:@"loading class %@ of NSBundle at %@ failed for some unknown reason", a1, a2];
		break;
	case ErrSigningNeeded:
		desc = [desc initWithFormat:@"collector %@ needs signing and we aren't signed", va_arg(ap, NSString *)];
		break;
	case ErrCannotCollectArtwork:
		desc = [desc initWithFormat:@"collector %@ can't be used to get album artwork counts", va_arg(ap, NSString *)];
		break;
	default:
		desc = [desc initWithFormat:@"(unknown error code %ld)", (long) errcode];
	}
	va_end(ap);
	keys[n] = NSLocalizedDescriptionKey;
	values[n] = desc;
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
