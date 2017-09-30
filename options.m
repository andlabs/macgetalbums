// 30 september 2017
#import "macgetalbums.h"

// TODO decide whether to allow aliased names or not
// TODO possibly drop getopt() entirely

Options *options;

enum {
	typeBool,
	typeString,
};

@interface optEntry : NSObject {
	int charName;
	NSString *longName;
	int type;
	NSString *helpText;
	NSValue *value;
}
- (id)initWithChar:(int)c longName:(NSString *)ln type:(int)t helpText:(NSString *)ht defaultValue:(NSValue *)dv;
- (int)charName;
- (NSString *)longName;
- (NSString *)helpText;
- (NSValue *)value;
- (void)optionPassed:(const char *)arg;
- (NSString *)accessorEncoding;
- (BOOL)boolAccessor;
- (const char *)stringAccessor;
@end

@implementation optEntry

- (id)initWithChar:(int)c longName:(NSString *)ln type:(const char *)t helpText:(NSString *)ht defaultValue:(NSValue *)dv
{
	self = [super init];
	if (self) {
		self->charName = c;
		self->longName = ln;
		if (self->longName != nil)
			[self->longName retain];
		self->type = t;
		self->helpText = ht;
		[self->helpText retain];
		self->value = dv;
		if (self->value == nil)
			switch (self->type) {
			case typeBool:
				self->defaultValue = [NSNumber numberWithBool:NO];
				break;
			case typeString:
				self->defaultValue = [NSValue valueWithPointer:NULL];
				break;
			}
		[self->value retain];
	}
	return self;
}

- (void)dealloc
{
	[self->value release];
	[self->helpText release];
	if (self->longName != nil)
		[self->longName release];
	[super dealloc];
}

- (int)charName
{
	return self->charName;
}

- (NSString *)longName
{
	return self->longName;
}

- (NSString *)helpText
{
	return self->helpText;
}

- (NSValue *)value
{
	return self->value;
}

- (void)optionPassed:(const char *)arg
{
	[self->value release];
	switch (self->type) {
	case typeBool:
		self->value = [[NSNumber alloc] initWithBool:YES];
		break;
	case typeString:
		self->value = [[NSValue alloc] initWithPointer:arg];
		break;
	}
}

// you own the returned string
- (NSString *)accessorEncoding
{
	const char *rt;

	switch (self->type) {
	case typeBool:
		rt = @encode(BOOL);
		break;
	case typeString:
		rt = @encode(const char *);
		break;
	default:
		// TODO
		return nil;
	}
	return [[NSString alloc] initWithFormat:@"%s%s%s",
		rt, @encode(id), @encode(SEL)];
}

- (BOOL)boolAccessor
{
	return [((NSNumber *) (self->value)) boolValue];
}

- (const char *)stringAccessor
{
	return (const char *) [self->value pointerValue];
}

@end

// TODO should we use NSInvalidArgumentException or NSInternalInconsistencyException instead?
#define throwValidity(...) [NSException raise:NSGenericException format:__VA_ARGS__]

static void checkValidity(NSDictionary *opts, NSString *newIdent, int newChar, NSString *newLongName)
{
	optEntry *e;

	// TODO reserve --help instead maybe
	if (newChar == 'h')
		throwValidity(@"-h is reserved for help");
	if ([opts objectForKey:newIdent] != nil)
		throwValidity(@"an option with identifier %@ has already been added", newIdent);
	for (NSString *key in opts) {
		e = (optEntry *) [opts objectForKey:key];
		if (newChar != 0 && [e char] == newChar)
			throwValidity(@"an option -%c has already been added with identifier %@", newChar, key);
		if (newLongName != nil && [[e longName] isEqual:newLongName])
			throwValidity(@"an option -%@ has already been added with identifier %@", newLongName, key);
	}
}

@implementation Options

- (id)initWithArgv0:(const char *)a0
{
	self = [super init];
	if (self) {
		self->argv0 = a0;
		self->options = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	[self->options release];
	[super dealloc];
}

- (void)addBoolOpt:(NSString *)ident char:(int)c helpText:(NSString *)helpText
{
	optEntry *e;

	checkValidity(self->options, ident, c, nil);
	e = [[optEntry alloc] initWithChar:c
		longName:nil
		type:typeBool
		helpText:helpText
		defaultValue:nil];
	[self->options setObject:e forKey:ident];
	[e release];
}

- (void)addStringOpt:(NSString *)ident char:(int)c defaultValue:(const char *)def helpText:(NSString *)helpText
{
	optEntry *e;

	checkValidity(self->options, ident, c, nil);
	e = [[optEntry alloc] initWithChar:c
		longName:nil
		type:typeString
		helpText:helpText
		defaultValue:[NSValue valueWithPointer:def]];
	[self->options setObject:e forKey:ident];
	[e release];
}

- (int)parse:(int)argc argv:(char **)argv
{
	NSMutableString *optstring;
	const char *optstr;
	struct option *longopts = NULL;
	NSMutableArray *shortEntries;
	NSMutableArray *longEntries;
	optEntry *e;
	int c, index;

	optstring = [NSMutableString new];
	shortEntries = [NSMutableDictionary new];
	longEntries = [NSMutableArray new];
	for (e in self->options) {
		if ([e charName] != nil) {
			[optstring appendFormat:@"%c", [e charName]];
			if ([e type] != optBool)
				[optstring appendString:@":"];
			[shortEntries setObject:e
				forKey:[NSNumber numberWithInt:[e charName]]];
		}
		if ([e longName] != nil)
			[longEntries addObject:e];
	}
	if ([optstring isEqual:@""])
		optstr = NULL;
	else {
		[optstring insertString:@"+:" atIndex:0];
		optstr = [optstring UTF8String];
	}
	if ([longEntries count] != 0) {
		size_t losize;
		struct option *loptr;

		losize = ([longEntries count] + 1) * sizeof (struct option);
		longopts = (struct option *) malloc(losize);
		// TODO check error
		memset(longopts, 0, losize);
		loptr = longopts;
		for (e in longEntries) {
			loptr->name = [[e longName] UTF8String];
			loptr->has_arg = no_argument;
			if ([e type] != typeBool)
				loptr->has_arg = required_argument;
			loptr->flag = NULL;
			loptr->val = 1000;
			loptr++;
		}
	}

	optreset = 1;
	for (;;) {
		NSNumber *n;
		optEntry *ne;
		int curind;

		curind = optind;
		c = getopt_long_only(argc, argv,
			optstr, longopts, &index);
		if (c == -1)
			break;

		// long option?
		if (c == 1000) {
			optEntry *e;

			e = [longEntries objectAtIndex:index];
			[e optionPassed:optarg];
			continue;
		}

		// short option?
		n = [[NSNumber alloc] initWithInt:c];
		ne = (optEntry *) [shortOptions objectForKey:n];
		[n release];
		if (ne != nil) {
			[ne optionPassed:optarg];
			continue;
		}

		// something else (-h, unknown, or invalid)
		// HACK-O-RAMA here, observing OS X's implementation of getopt_long() shows this code *should* work — see also https://stackoverflow.com/questions/2723888/where-does-getopt-long-store-an-unrecognized-option
		switch (c) {
		case '?':
			if (optopt == 0)
				xfprintf(stderr, @"error: unknown option %s\n", argv[curind]);
			else
				xfprintf(stderr, @"error: unknown option -%c\n", optopt);
			break;
		case ':':
			if (optopt == 0 || optopt == 1000)
				xfprintf(stderr, @"error: option %s requires an argument\n", argv[curind]);
			else
				xfprintf(stderr, @"error: option -%c requires an argument\n", optopt);
			break;
		}
		[self usage];
	}

	if (longopts != NULL)
		free(longopts);
	[longEntries release];
	[shortEntries release];
	[optstring release];
	return optind;
}

- (void)usage
{
}

@end
