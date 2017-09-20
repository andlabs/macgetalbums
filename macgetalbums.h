// 7 august 2017
// TODO move file-specific headers out of here
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import <Security/Security.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <math.h>
#import <unistd.h>
#import <stdarg.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>
#import "iTunes.h"

// TODO damn MacTypes.h
#define Duration mgaDuration

// timer.m
enum {
	TimerLoad = 1,
	TimerCollect,
	TimerSort,
	nTimers,
};
@interface Timer : NSObject {
	int cur;
	uint64_t starts[nTimers];
	uint64_t ends[nTimers];
}
- (void)start:(int)t;
- (void)end;
- (uint64_t)nanoseconds:(int)t;
- (double)seconds:(int)t;
@end

// duration.m
// TODO swap seconds and ms? seconds came first
@interface Duration : NSObject<NSCopying> {
	BOOL hasSeconds;
	NSUInteger msec;
	double sec;
}
- (id)initWithMilliseconds:(NSUInteger)val;
- (id)initWithSeconds:(double)val;
- (void)add:(Duration *)d;
- (void)addMilliseconds:(NSUInteger)val;
- (void)addSeconds:(double)val;
- (NSUInteger)milliseconds;
@end

// item.m
@interface Item : NSObject<NSCopying> {
	NSInteger year;
	NSString *artist;
	NSString *album;
	Duration *length;
}
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa length:(Duration *)l;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthMilliseconds:(NSUInteger)ms;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthSeconds:(double)sec;
- (NSInteger)year;
// TODO replace this with combineWith:
- (void)setYear:(NSInteger)year;
- (NSString *)artist;
- (NSString *)album;
- (Duration *)length;
@end

// scriptingbridge.m and ituneslibrary.m
@protocol Collector<NSObject>
// TODO apparently this isn't in the NSObject protocol?
+ (instancetype)alloc;
+ (NSString *)collectorDescription;
+ (BOOL)needsSigning;
// TODO canGetArtworkCount (iTunesLibrary can't? TODO)
- (id)initWithTimer:(Timer *)t error:(NSError **)err;
- (NSArray *)collectTracks;
@end
@interface ScriptingBridgeCollector : NSObject<Collector>
@end
@interface iTunesLibraryCollector : NSObject<Collector>
@end

// amisigned.m
extern BOOL amISigned;
extern OSStatus amISignedErr;
extern BOOL checkIfSigned(void);
