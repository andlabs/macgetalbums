// 1 october 2017
#import <Foundation/Foundation.h>

// flag.m
@interface FlagSet : NSObject {
	const char *argv0;
	NSMutableDictionary *flagValues;
}
- (id)initWithArgv0:(const char *)a0;
- (const char *)argv0;

// Note the add methods are class methods; flags are associated with a class. Therefore, you must subclass FlagSet.
// Use the AddFlag() macros below to wrap calls to these around selectors.
+ (void)addBoolFlag:(NSString *)name defaultValue:(BOOL)defaultValue helpText:(NSString *)helpText;
- (BOOL)valueOfBoolFlag:(NSString *)name;
+ (void)addStringFlag:(NSString *)name defaultValue:(const char *)def helpText:(NSString *)helpText;
- (const char *)valueOfStringFlag:(NSString *)name;

// Returns the number of entries of list processed; you can add that to list and subtract it from n to get the non-flag arguments.
- (int)parseStringList:(const char **)list count:(int)n;
// Equivalent to [self parseStringList:(argv + 1) count:(argc - 1)] + 1.
// Use this on the initial argc/argv passed to main().
// Note that this does not change argv0; use -initWithArgv0: instead.
- (int)parseArgc:(int)argc argv:(const char **)argv;

+ (void)usage;
// Equivalent to [[self class] usage]; provided for convenience.
- (void)usage;
// This will always end with a newline.
+ (NSString *)copyUsageText;
// Override this to add custom text after the standard text.
// If non-nil, it should end with a newline; if not, -copyUsageText will add one.
+ (NSString *)copyUsageTrailingLines;
@end

// cls - the class to add the flag to (must subclass FlagSet)
// selector - the selector to use to access the flag from code (must be a single C identifier and takes no arguments)
// name - a NSString with the flag name used on the command line (so for -v, use @"v"; for -print or --print, use @"print")
// ctype - the C type of the value of the flag
// typenamepart - the part of the selector names in FlagSet for the given ctype
// defval - the default value of the flag
// help - a NSString with the help text of the flag
#define AddFlag(cls, selector, name, ctype, typenamepart, defval, help) \
	@interface cls (selector ## Flag) \
	- (ctype)selector; \
	@end \
	@implementation cls (selector ## Flag) \
	+ (void)load \
	{ \
		[self add ## typenamepart ## Flag:name \
			defaultValue:defval \
			helpText:help]; \
	} \
	- (ctype)selector \
	{ \
		return [self valueOf ## typenamepart ## Flag:name]; \
	} \
	@end

#define AddBoolFlag(cls, selector, name, help) \
	AddFlag(cls, selector, name, BOOL, Bool, NO, help)
#define AddStringFlag(cls, selector, name, defval, help) \
	AddFlag(cls, selector, name, const char *, String, defval, help)
