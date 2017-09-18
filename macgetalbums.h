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
#import <mach/mach.h>
#import <mach/mach_time.h>
#import "iTunes.h"

// timer.m
@interface Timer : NSObject {
	uint64_t start, end;
}
- (void)start;
- (void)end;
- (uint64_t)nanoseconds;
- (double)seconds;
@end

// duration.m
// TODO swap seconds and ms? seconds came first
@interface Duration : NSObject {
	BOOL hasSeconds;
	NSUInteger msec;
	double sec;
}
- (id)initWithMilliseconds:(NSUInteger)val;
- (id)initWithSeconds:(double)val;
- (void)addMilliseconds:(NSUInteger)val;
- (void)addSeconds:(double)val;
- (NSUInteger)milliseconds;
@end

// item.m
@interface Item : NSObject {
	NSInteger year;
	NSString *artist;
	NSString *album;
	Duration *duration;
}
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa length:(Duration *)l;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthMilliseconds:(NSUinteger)ms;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthSeconds:(double)sec;
- (NSInteger)year;
- (NSString *)artist;
- (NSString *)album;
- (Duration *)length;
@end

// scriptingbridge.m and ituneslibrary.m
@protocol Collector<NSObject>
+ (NSString *)collectorName;
+ (BOOL)canRun;
// TODO canGetArtworkCount (iTunesLibrary can't? TODO)
// TODO init storing time to init
- (NSArray *)collectTracks:(double *)duration;
@end
@class ScriptingBridgeCollector<Collector>;
@class iTunesLibraryCollector<Collector>;

// amisigned.m
extern BOOL amISigned;
extern OSStatus amISignedErr;
extern BOOL checkIfSigned(void);
