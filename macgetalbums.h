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

// item.m
@interface Item : NSObject
// TODO make lowercase?
@property NSInteger Year;
@property (strong) NSString *Artist;
@property (strong) NSString *Album;
@property double Length;
- (NSString *)lengthString;
// TODO make this automatic, possibly part of init
- (void)handleOverrides;
@end

// scriptingbridge.m and ituneslibrary.m
@protocol Collector<NSObject>
+ (BOOL)canRun;
// TODO canGetArtworkCount (iTunesLibrary can't? TODO)
// TODO init storing time to init
- (NSArray *)collectTracks:(double *)duration;
@end
@class ScriptingBridgeCollector : Collector;
@class iTunesLibraryCollector : Collector;

// amisigned.m
extern BOOL amISigned(OSStatus *err);
