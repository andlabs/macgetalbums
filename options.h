// 1 october 2017

// options.m
@interface Options : NSObject {
	const char *argv0;
	NSMutableDictionary *options;
	NSMutableDictionary *optsByAccessor;
}
- (id)initWithArgv0:(const char *)a0;
- (const char *)argv0;
- (BOOL)boolForAccessorImpl;
- (void)addBoolOpt:(NSString *)name helpText:(NSString *)helpText;
- (void)addBoolOpt:(NSString *)name helpText:(NSString *)helpText accessor:(NSString *)accessor;
- (const char *)stringForAccessorImpl;
- (void)addStringOpt:(NSString *)name defaultValue:(const char *)def helpText:(NSString *)helpText;
- (void)addStringOpt:(NSString *)name defaultValue:(const char *)def helpText:(NSString *)helpText accessor:(NSString *)accessor;
- (int)parse:(int)argc argv:(char **)argv;
- (void)usage;
@end
