// 30 september 2017
#import "macgetalbums.h"

Options *options;

@interface optEntry : NSObject {
	NSString *name;
	NSValue *value;
	NSString *helpText;
}
- (id)initWithName:(NSString *)n defaultValue:(NSValue *)dv helpText:(NSString *)ht;
- (NSString *)name;
- (NSValue *)value;
- (void)setValue:(NSValue *)v;
- (NSString *)helpText;
- (BOOL)takesArgument;
- (NSString *)argumentDescription;
- (void)optionPassed:(const char *)arg;
@end

@implementation optEntry

- (id)initWithName:(NSString *)n defaultValue:(NSValue *)dv helpText:(NSString *)ht
{
	self = [super init];
	if (self) {
		self->name = n;
		[self->name retain];
		self->value = dv;
		[self->value retain];
		self->helpText = ht;
		[self->helpText retain];
	}
	return self;
}

- (void)dealloc
{
	[self->helpText release];
	[self->value release];
	[self->name release];
	[super dealloc];
}

- (NSString *)name
{
	return self->name;
}

- (NSValue *)value
{
	return self->value;
}

- (void)setValue:(NSValue *)v
{
	[self->value release];
	self->value = v;
	[self->value retain];
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

- (void)optionPassed:(const char *)arg
{
	[self doesNotRecognizeSelector:_cmd];
}

@end

@interface optBoolEntry : optEntry
- (id)initWithName:(NSString *)n helpText:(NSString *)ht;
@end

@implementation optBoolEntry

- (id)initWithName:(NSString *)n helpText:(NSString *)ht
{
	return [super initWithName:n
		defaultValue:[NSNumber numberWithBool:NO]
		helpText:ht];
}

- (BOOL)takesArgument
{
	return NO;
}

- (void)optionPassed:(const char *)arg
{
	[self setValue:[NSNumber numberWithBool:YES]];
}

@end

@interface optStringEntry : optEntry
- (id)initWithName:(NSString *)n defaultString:(const char *)ds helpText:(NSString *)ht;
@end

@implementation optStringEntry

- (id)initWithName:(NSString *)n defaultString:(const char *)ds helpText:(NSString *)ht;
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

- (void)optionPassed:(const char *)arg
{
	[self setValue:[NSValue valueWithPointer:arg]];
}

@end

@implementation Options

- (id)initWithArgv0:(const char *)a0
{
	self = [super init];
	if (self) {
		self->argv0 = a0;
		self->options = [NSMutableDictionary new];
		self->optsByAccessor = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	[self->optsByAccessor release];
	[self->options release];
	[super dealloc];
}

- (const char *)argv0
{
	return self->argv0;
}

- (BOOL)boolForAccessorImpl
{
	NSString *str;
	optEntry *e;
	NSNumber *n;

	if (_cmd == @selector(boolForAccessorImpl))
		[self doesNotRecognizeSelector:_cmd];
	str = NSStringFromSelector(_cmd);
	// TODO do we own str?
	e = (optEntry *) [self->optsByAccessor objectForKey:str];
	n = (NSNumber *) [e value];
	return [n boolValue];
}

- (void)addBoolOpt:(NSString *)name helpText:(NSString *)helpText
{
	[self addBoolOpt:name helpText:helpText accessor:name];
}

- (void)addBoolOpt:(NSString *)name helpText:(NSString *)helpText accessor:(NSString *)accessor
{
	optBoolEntry *e;
	SEL newsel, isel;

	e = [[optBoolEntry alloc] initWithName:name
		helpText:helpText];
	[self->options setObject:e forKey:name];

	[self->optsByAccessor setObect:e forKey:accessor];
	newsel = NSStringToSelector(accessor);
	isel = @selector(boolForAccessorImpl);
	addMethod([self class], newsel, isel);

	[e release];
}

- (const char *)stringForAccessorImpl
{
	NSString *str;
	optEntry *e;
	NSValue *v;

	if (_cmd == @selector(boolForAccessorImpl))
		[self doesNotRecognizeSelector:_cmd];
	str = NSStringFromSelector(_cmd);
	// TODO do we own str?
	e = (optEntry *) [self->optsByAccessor objectForKey:str];
	v = (NSValue *) [e value];
	return (const char *) [n pointerValue];
}

- (void)addStringOpt:(NSString *)name defaultValue:(const char *)def helpText:(NSString *)helpText
{
	[self addStringOpt:name defaultValue:def helpText:helpText accessor:name];
}

- (void)addStringOpt:(NSString *)name defaultValue:(const char *)def helpText:(NSString *)helpText accessor:(NSString *)accessor
{
	optStringEntry *e;
	SEL newsel, isel;

	e = [[optStringEntry alloc] initWithName:name
		defaultString:def
		helpText:helpText];
	[self->options setObject:e forKey:name];

	[self->optsByAccessor setObect:e forKey:accessor];
	newsel = NSStringToSelector(accessor);
	isel = @selector(stringForAccessorImpl);
	addMethod([self class], newsel, isel);

	[e release];
}

- (int)parse:(int)argc argv:(char **)argv
{
	const char *optname;
	const char *optnameend;
	NSData *optnamedata;
	NSString *optnamestr;
	const char *optarg;
	optEntry *e;
	int i;

	for (i = 1; i < argc; i++) {
		// -- marks the end of flags
		if (strcmp(argv[i], "--") == 0) {
			i++;
			break;
		}
		// - does too, but is an argument as well
		if (strcmp(argv[i], "-") == 0)
			break;
		// and handle the obvious cases
		// the first one shouldn't happen but let's be safe
		// the second one is the first argument
		if (argv[i] == NULL || argv[i][0] != '-')
			break;

		// strip the leading dashes and extract the name
		optname = argv[i];
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
		optnamestr = [[NSString alloc] initWithData:argnamedata
			encoding:NSUTF8StringEncoding];
		[optnamedata release];

		// Go's package flag doesn't care if this has an argument
		if ([optnamestr isEqual:@"help"] || [optnamestr isEqual:@"h"])
			[self usage];

		e = [self->options objectForKey:optnamestr];
		if (e == nil) {
			xfprintf(stderr, @"error: unknown option -%@\n", optnamestr);
			[self usage];
		}

		optarg = NULL;
		if (*optnameend == '=') {
			optarg = optnameend;
			optarg++;
		}
		if (optarg != NULL && ![e takesArgument]) {
			xfprintf(stderr, @"error: option -%@ does not take an argument\n", optnamestr);
			[self usage];
		}
		// consume the next argument as the option's argument if needed
		if (optarg == NULL && [e takesArgument]) {
			i++;
			if (i == argc) {
				xfprintf(stderr, @"error: option -%@ requires an argument\n", optnamestr);
				[self usage];
			}
			optarg = argv[i];
		}

		[e optionPassed:optarg];

		[optnamestr release];
	}

	return i;
}

- (void)usage
{
	NSArray *optsInOrder;
	optEntry *e, *helpEntry;

	xfprintf(stderr, @"usage: %s [options]\n", self->argv0);

	@autoreleasepool {
		optsInOrder = [self->options allKeys];
		optsInOrder = [optsInOrder arrayByAddingObject:@"help/-h"];
		optsInOrder = [optsInOrder sortedArrayUsingSelector:@selector(compare:)];
		[optsInOrder retain];
	}
	helpEntry = [[optBoolEntry alloc] initWithName:@"help" helpText:@"show this help and quit"];
	for (NSString *opt in optsInOrder) {
		e = (optEntry *) [self->options objectForKey:opt];
		if (e == nil)
			e = helpEntry;

		// Go's package flag does the specific spacing internally for good alignment on both 4-space and 8-space tabs
		xfprintf(stderr, @"  -%@", opt);
		if ([e takesArgument])
			xfprintf(stderr, @" %@", [e argumentDescription]);
		if ([opt length] == 1 && ![e takesArgument])
			xfprintf(stderr, @"\t");
		else
			xfprintf(stderr, @"\n    \t");
		xfprintf(stderr, @"%@", [e helpText]);
		// TODO print default values the same way as in Go
		xfprintf(stderr, @"\n");
	}

	// TODO additional usage notes

	[helpEntry release];
	[optsInOrder release];
	exit(1);
}

@end
