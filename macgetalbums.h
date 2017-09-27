// 7 august 2017
// TODO move file-specific headers out of here
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import <Security/Security.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <math.h>
#import <unistd.h>
#import <stdarg.h>
#import <inttypes.h>
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
// you own the returned string
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
// you own the returned string
- (NSString *)stringWithOnlyMinutes:(BOOL)onlyMinutes;
@end

// track.m
struct trackParams {
	NSInteger year;
	NSString *artist;
	NSString *album;
	NSString *title;
	NSInteger trackNumber;
	NSInteger trackCount;
	NSInteger discNumber;
	NSInteger discCount;
	NSUInteger artworkCount;
};
@interface Item : NSObject {
	NSInteger year;
	NSString *artist;
	NSString *album;
	Duration *length;
	NSString *title;
	NSInteger trackNumber;
	NSInteger trackCount;
	NSInteger discNumber;
	NSInteger discCount;
	NSUInteger artworkCount;
}
- (id)initWithParams:(struct trackParams *)p length:(Duration *)l;
- (id)initWithParams:(struct trackParams *)p lengthMilliseconds:(NSUInteger)ms;
- (id)initWithParams:(struct trackParams *)p lengthSeconds:(double)sec;
- (NSInteger)year;
- (NSString *)artist;
- (NSString *)album;
- (Duration *)length;
// you own the returned string
- (NSString *)formattedNumberTitleArtistAlbum;
- (NSUInteger)artworkCount;
@end

// album.m
extern NSString *const compilationArtist;
@interface Album : NSObject {
	NSInteger year;
	NSString *artist;
	NSString *album;
	Duration *length;
	NSInteger trackCount;
	NSInteger discCount;
	id<NSObject> firstTrack;		// for saving during collection to figure out what to get artwork from; should be nil afterwards
	NSImage *firstArtwork;
}
- (id)initWithYear:(NSInteger)year artist:(NSString *)a album:(NSString *)al;
- (void)addTrack:(Track *)t;
- (NSInteger)year;
- (NSString *)artist;
- (NSString *)album;
- (Duration *)length;
- (NSInteger)trackCount;
- (NSInteger)discCount;
- (id<NSObject>)firstTrack;
- (void)setFirstTrack:(id<NSObject>)ft;
- (NSImage *)firstArtwork;
- (void)setFirstArtworkAndReleaseFirstTrack:(NSImage *)a;
@end

// collector.m
@protocol Collector<NSObject>
// apparently this isn't in the NSObject protocol, but we need it
+ (instancetype)alloc;
+ (NSString *)collectorDescription;
+ (BOOL)needsSigning;
+ (BOOL)canGetArtworkCount;
// you own the returned error
- (id)initWithTimer:(Timer *)t error:(NSError **)err;
// you own the returned array and set
- (NSArray *)collectTracksAndAlbums:(NSSet **)albums;
@end
extern NSArray *defaultCollectorsArray(void);
extern NSArray *singleCollectorArray(const char *what);
typedef BOOL (*foreachCollectorFunc)(NSString *name, Class<Collector> class, void *data);
extern void foreachCollector(NSArray *collectors, foreachCollectorFunc f, void *data);

// scriptingbridge.m
@interface ScriptingBridgeCollector : NSObject<Collector>
@end

// ituneslibrarycontroller.m
@interface iTunesLibraryCollector : NSObject<Collector>
@end

// issigned.m
extern BOOL checkIfSigned(NSError **err);

// pdf.m
extern CFDataRef makePDF(NSSet *albums, BOOL onlyMinutes);

// printlog.m
extern void xvfprintf(FILE *f, NSString *fmt, va_list ap);
extern void xfprintf(FILE *f, NSString *fmt, ...);
extern void xprintf(NSString *fmt, ...);
extern void xstderrprintf(NSString *fmt, ...);
extern BOOL suppressLogs;
extern void xlogv(NSString *fmt, va_list ap);
extern void xlog(NSString *fmt, ...);
extern void xlogtimer(NSString *msg, Timer *timer, int which);

// errors.m
extern NSString *const ErrDomain;
enum {
	ErrBundleInitFailed,			// args: framework bundle path (NSString *)
	ErrBundleLoadFailed,		// args: framework bundle path (NSString *)
	ErrBundleClassNameFailed,	// args: class name (NSString *), framework bundle path (NSString *)
	ErrSigningNeeded,			// args: collector name (NSString *)
	ErrCannotCollectArtwork,		// args: collector name (NSString *)
};
extern NSError *makeError(NSInteger errcode, ...);
