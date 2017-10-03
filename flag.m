// 30 september 2017
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <stdarg.h>
#import "flag.h"

@interface flag : NSObject {
	NSString *name;
	NSValue *defaultValue;
	NSString *helpText;
}
- (id)initWithName:(NSString *)n defaultValue:(NSValue *)dv helpText:(NSString *)ht;
- (NSString *)name;
- (NSValue *)defaultValue;
- (NSString *)helpText;
- (BOOL)takesArgument;
- (NSString *)argumentDescription;
- (NSValue *)valueWithArgument:(const char *)arg;
@end

@implementation flag

- (id)initWithName:(NSString *)n defaultValue:(NSValue *)dv helpText:(NSString *)ht
{
	self = [super init];
	if (self) {
		self->name = n;
		[self->name retain];
		self->defaultValue = dv;
		[self->defaultValue retain];
		self->helpText = ht;
		[self->helpText retain];
	}
	return self;
}

- (void)dealloc
{
	[self->helpText release];
	[self->defaultValue release];
	[self->name release];
	[super dealloc];
}

- (NSString *)name
{
	return self->name;
}

- (NSValue *)defaultValue
{
	return self->defaultValue;
}

- (NSString *)helpText
{
	return self->helpText;
}

- (BOOL)takesArgument
{
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (NSString *)argumentDescription
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSValue *)valueWithArgument:(const char *)arg
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end

@interface boolFlag : flag
- (id)initWithName:(NSString *)n defaultBool:(BOOL)b helpText:(NSString *)ht;
@end

@implementation boolFlag

- (id)initWithName:(NSString *)n defaultBool:(BOOL)b helpText:(NSString *)ht
{
	return [super initWithName:n
		defaultValue:[NSNumber numberWithBool:b]
		helpText:ht];
}

- (BOOL)takesArgument
{
	return NO;
}

- (NSValue *)valueWithArgument:(const char *)arg
{
	return [NSNumber numberWithBool:YES];
}

@end

@interface stringFlag : flag
- (id)initWithName:(NSString *)n defaultString:(const char *)ds helpText:(NSString *)ht;
@end

@implementation stringFlag

- (id)initWithName:(NSString *)n defaultString:(const char *)ds helpText:(NSString *)ht
{
	return [super initWithName:n
		defaultValue:[NSValue valueWithPointer:ds]
		helpText:ht];
}

- (BOOL)takesArgument
{
	return YES;
}

- (NSString *)argumentDescription
{
	return @"string";
}

- (NSValue *)valueWithArgument:(const char *)arg
{
	return [NSValue valueWithPointer:arg];
}

@end

// TODO see if we can get rid of this
static void xfprintf(FILE *f, NSString *fmt, ...)
{
	NSString *msg;
	va_list ap;

	va_start(ap, fmt);
	msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	fprintf(f, "%s", [msg UTF8String]);
	[msg release];
	va_end(ap);
}

// map[Class]map[string]flag
static NSMutableDictionary *flags = nil;
static NSMutableSet *finished = nil;

// subclasses don't call the superclass's +load, so we have to do this on each call to one of the +addFlag methods
static void registerSubclass(Class subclass)
{
	NSMutableDictionary *m;

	m = (NSMutableDictionary *) [flags objectForKey:subclass];
	if (m == nil) {
		m = [NSMutableDictionary new];
		// the cast is necessary because of more miswritten header files! yay!
		[flags setObject:m forKey:((id<NSCopying>) subclass)];
		[m release];
	}
}

// TODO this is the same exception thrown by -doesNotRecognizeSelector: but that isn't a class method?
#define mustSubclass() \
	if ([self class] == [FlagSet class]) \
		[NSException raise:NSInvalidArgumentException \
			format:@"you cannot call %c%@ on FlagSet directly; you must subclass it", (([self class] == self) ? '+' : '-'), NSStringFromSelector(_cmd)];

@implementation FlagSet

+ (void)load
{
	if (flags == nil)
		flags = [NSMutableDictionary new];
	if (finished == nil)
		finished = [NSMutableSet new];
}

- (id)init
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithArgv0:(const char *)a0
{
	mustSubclass();
	self = [super init];
	if (self) {
		NSDictionary *cf;

		[finished addObject:[self class]];
		self->argv0 = a0;
		self->flagValues = [NSMutableDictionary new];
		cf = (NSDictionary *) [flags objectForKey:[self class]];
		for (NSString *name in cf) {
			flag *f;

			f = (flag *) [cf objectForKey:name];
			[self->flagValues setObject:[f defaultValue]
				forKey:name];
		}
	}
	return self;
}

- (void)dealloc
{
	[self->flagValues release];
	[super dealloc];
}

- (const char *)argv0
{
	return self->argv0;
}

#define mustNotBeFinished() \
	if ([finished containsObject:self]) \
		[NSException raise:NSInvalidArgumentException \
			format:@"cannot add a flag to flag set %@ after an instance has been created", NSStringFromClass(self)];
#define mustBeUnique(cf, name) \
	if ([cf objectForKey:name] != nil) \
		[NSException raise:NSInvalidArgumentException \
			format:@"flag set %@ already has a flag -%@; cannot add another", NSStringFromClass(self), name];
#define mustExist(name, obj) \
	if (obj == nil) \
		[NSException raise:NSInvalidArgumentException \
			format:@"flag set %@ has no flag -%@ to get the value of", NSStringFromClass([self class]), name];

+ (void)addBoolFlag:(NSString *)name defaultValue:(BOOL)defaultValue helpText:(NSString *)helpText
{
	NSMutableDictionary *cf;
	boolFlag *f;

	mustSubclass();
	mustNotBeFinished();
	registerSubclass(self);
	cf = (NSMutableDictionary *) [flags objectForKey:self];
	mustBeUnique(cf, name);
	f = [[boolFlag alloc] initWithName:name
		defaultBool:defaultValue
		helpText:helpText];
	[cf setObject:f forKey:name];
	[f release];
}

- (BOOL)valueOfBoolFlag:(NSString *)name
{
	NSNumber *n;

	n = (NSNumber *) [self->flagValues objectForKey:name];
	mustExist(name, n);
	return [n boolValue];
}

+ (void)addStringFlag:(NSString *)name defaultValue:(const char *)defaultValue helpText:(NSString *)helpText
{
	NSMutableDictionary *cf;
	stringFlag *f;

	mustSubclass();
	mustNotBeFinished();
	registerSubclass(self);
	cf = (NSMutableDictionary *) [flags objectForKey:self];
	mustBeUnique(cf, name);
	f = [[stringFlag alloc] initWithName:name
		defaultString:defaultValue
		helpText:helpText];
	[cf setObject:f forKey:name];
	[f release];
}

- (const char *)valueOfStringFlag:(NSString *)name
{
	NSValue *v;

	v = (NSValue *) [self->flagValues objectForKey:name];
	mustExist(name, v);
	return (const char *) [v pointerValue];
}

- (int)parseStringList:(char **)list count:(int)n
{
	const char *optname;
	const char *optnameend;
	NSData *optnamedata;
	NSString *optnamestr;
	const char *optarg;
	NSDictionary *cf;
	flag *f;
	int i;

	cf = (NSDictionary *) [flags objectForKey:[self class]];
	for (i = 0; i < n; i++) {
		// -- marks the end of flags
		if (strcmp(list[i], "--") == 0) {
			i++;
			break;
		}
		// - does too, but is an argument as well
		if (strcmp(list[i], "-") == 0)
			break;
		// and handle the obvious cases
		// the first one shouldn't happen but let's be safe
		// the second one is the first argument
		if (list[i] == NULL || list[i][0] != '-')
			break;

		// strip the leading dashes and extract the name
		optname = list[i];
		if (optname[0] == '-')
			optname++;
		if (optname[0] == '-')
			optname++;
		optnameend = optname;
		while (*optnameend != '\0' && *optnameend != '=')
			optnameend++;
		// argh -[NSString initWithBytes:length:encoding:] was introduced in 10.3
		optnamedata = [[NSData alloc] initWithBytes:optname
			length:(optnameend - optname)];
		optnamestr = [[NSString alloc] initWithData:optnamedata
			encoding:NSUTF8StringEncoding];
		[optnamedata release];

		// Go's package flag doesn't care if this has an argument
		if ([optnamestr isEqual:@"help"] || [optnamestr isEqual:@"h"])
			[self usage];

		f = (flag *) [cf objectForKey:optnamestr];
		if (f == nil) {
			xfprintf(stderr, @"error: unknown option -%@\n", optnamestr);
			[self usage];
		}

		optarg = NULL;
		if (*optnameend == '=') {
			optarg = optnameend;
			optarg++;
		}
		if (optarg != NULL && ![f takesArgument]) {
			xfprintf(stderr, @"error: option -%@ does not take an argument\n", optnamestr);
			[self usage];
		}
		// consume the next argument as the option's argument if needed
		if (optarg == NULL && [f takesArgument]) {
			i++;
			if (i == n) {
				xfprintf(stderr, @"error: option -%@ requires an argument\n", optnamestr);
				[self usage];
			}
			optarg = list[i];
		}

		[self->flagValues setObject:[f valueWithArgument:optarg]
			forKey:optnamestr];

		[optnamestr release];
	}

	return i;
}

- (int)parseArgc:(int)argc argv:(char **)argv
{
	return [self parseStringList:(argv + 1) count:(argc - 1)] + 1;
}

+ (void)usage:(const char *)argv0
{
	NSString *str;

	str = [self copyUsageText:argv0];
	fprintf(stderr, "%s", [str UTF8String]);
	[str release];
	exit(1);
}

- (void)usage
{
	[[self class] usage:[self argv0]];
}

// TODO should this finalize options?
+ (NSString *)copyUsageText:(const char *)argv0
{
	NSMutableString *ret;
	NSDictionary *cf;
	NSArray *sortedFlags;
	flag *f, *helpFlag;
	NSString *trailing;

	ret = [[NSMutableString alloc] initWithFormat:@"usage: %s [options]\n", argv0];

	cf = (NSDictionary *) [flags objectForKey:self];
	@autoreleasepool {
		sortedFlags = [cf allKeys];
		sortedFlags = [sortedFlags arrayByAddingObject:@"help/-h"];
		sortedFlags = [sortedFlags sortedArrayUsingSelector:@selector(compare:)];
		[sortedFlags retain];
	}

	helpFlag = [[boolFlag alloc] initWithName:@"help"
		defaultBool:NO
		helpText:@"show this help and quit"];

	for (NSString *name in sortedFlags) {
		f = (flag *) [cf objectForKey:name];
		if (f == nil)
			f = helpFlag;

		// Go's package flag does the specific spacing internally for good alignment on both 4-space and 8-space tabs
		[ret appendFormat:@"  -%@", name];
		if ([f takesArgument])
			[ret appendFormat:@" %@", [f argumentDescription]];
		if ([name length] == 1 && ![f takesArgument])
			[ret appendString:@"\t"];
		else
			[ret appendString:@"\n    \t"];
		[ret appendString:[f helpText]];
		// TODO print default values the same way as in Go
		[ret appendString:@"\n"];
	}

	trailing = [self copyUsageTrailingLines];
	if (trailing != nil) {
		[ret appendString:trailing];
		if (![trailing hasSuffix:@"\n"])
			[ret appendString:@"\n"];
		[trailing release];
	}

	[helpFlag release];
	[sortedFlags release];
	return ret;
}

+ (NSString *)copyUsageTrailingLines
{
	return nil;
}

@end
