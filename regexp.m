// 3 october 2017
#import "macgetalbums.h"

NSString *const RegexpErrDomain = @"com.andlabs.macgetalbums.RegexpErrorDomain";

static NSString *regerrorString(int err, const regex_t *preg)
{
	NSMutableData *data;
	size_t len;
	NSString *ret;

	len = regerror(err, preg, NULL, 0);
	data = [[NSMutableData alloc] initWithLength:len];
	regerror(err, preg, [data mutableBytes], len);
	// don't use initWithData:encoding: because that will add the null terminator to the string, leading to corrupt output when printed
	ret = [[NSString alloc] initWithUTF8String:[data bytes]];
	[data release];
	return ret;
}

@implementation Regexp

- (id)initWithRegexp:(const char *)re caseInsensitive:(BOOL)caseInsensitive error:(NSError **)err
{
	self = [super init];
	if (self) {
		int errcode;
		int opts;

		*err = nil;
		opts = 0;
		if (caseInsensitive)
			opts |= REG_ICASE;
		errcode = regcomp(&(self->preg), re,
			REG_EXTENDED | REG_NOSUB | opts);
		if (errcode == 0)
			self->valid = YES;
		else {
			NSString *errstr;
			NSDictionary *userInfo;

			self->valid = NO;
			errstr = regerrorString(errcode, &(self->preg));
			userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:errstr, NSLocalizedDescriptionKey, nil];
			[errstr release];
			*err = [[NSError alloc] initWithDomain:RegexpErrDomain
				code:errcode
				userInfo:userInfo];
			[userInfo release];
		}
	}
	return self;
}

- (void)dealloc
{
	if (self->valid)
		regfree(&(self->preg));
	[super dealloc];
}

- (BOOL)matches:(NSString *)str
{
	int err;

	err = regexec(&(self->preg), [str UTF8String],
		0, NULL, 0);
	if (err == 0)
		return YES;
	if (err != REG_NOMATCH) {
		NSString *errstr;

		errstr = regerrorString(err, &(self->preg));
		[NSException raise:NSInternalInconsistencyException
			format:@"unexpected error calling regmatch(): %@ (%d)", errstr, err];
	}
	return NO;
}

@end
