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

// damn MacTypes.h already having a Duration
#define Duration mgaDuration

// timer.m
enum {
	TimerLoad = 1,
	TimerCollect,
	TimerConvert,
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
- (NSString *)stringFor:(int)t;
@end

// duration.m
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
- (NSString *)stringWithOnlyMinutes:(BOOL)onlyMinutes;
@end

// item.m
extern NSString *const compilationArtist;
@interface Item : NSObject<NSCopying> {
	NSInteger year;
	NSString *artist;
	NSString *album;
	Duration *length;
	NSString *title;
	NSInteger trackNumber;
	NSInteger discNumber;
	NSUInteger artworkCount;
}
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa length:(Duration *)l title:(NSString *)tt trackNumber:(NSInteger)tn discNumber:(NSInteger)dn artworkCount:(NSUInteger)ac;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthMilliseconds:(NSUInteger)ms title:(NSString *)tt trackNumber:(NSInteger)tn discNumber:(NSInteger)dn artworkCount:(NSUInteger)ac;
- (id)initWithYear:(NSInteger)y trackArtist:(NSString *)ta album:(NSString *)a albumArtist:(NSString *)aa lengthSeconds:(double)sec title:(NSString *)tt trackNumber:(NSInteger)tn discNumber:(NSInteger)dn artworkCount:(NSUInteger)ac;
- (void)combineWith:(Item *)i2;
- (NSInteger)year;
- (NSString *)artist;
- (NSString *)album;
- (Duration *)length;
- (NSString *)formattedNumberTitleArtistAlbum;
- (NSUInteger)artworkCount;
@end

// scriptingbridge.m and ituneslibrary.m
@protocol Collector<NSObject>
// apparently this isn't in the NSObject protocol, but we need it
+ (instancetype)alloc;
+ (NSString *)collectorDescription;
+ (BOOL)needsSigning;
+ (BOOL)canGetArtworkCount;
// err is not owned by you on return
- (id)initWithTimer:(Timer *)t error:(NSError **)err;
// the returned array IS owned by you
- (NSArray *)collectTracks;
@end
@interface ScriptingBridgeCollector : NSObject<Collector>
@end
@interface iTunesLibraryCollector : NSObject<Collector>
@end

// issigned.m
extern BOOL checkIfSigned(NSError **err);

// errors.m
extern NSString *const ErrDomain;
enum {
	ErrSigningNeeded,			// args: collector name
	ErrCannotCollectArtwork,		// args: collector name
};
extern NSError *makeError(NSInteger errcode, ...);
