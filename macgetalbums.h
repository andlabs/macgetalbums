// 7 august 2017
// TODO move file-specific headers out of here
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import <Security/Security.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <math.h>
#import <unistd.h>
#import <stdarg.h>
#import <inttypes.h>
#import <regex.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import "iTunes.h"
#import "flag.h"

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
- (NSComparisonResult)compare:(Duration *)b;
@end

// track.m
struct trackParams {
	NSInteger year;
	NSString *trackArtist;
	NSString *album;
	NSString *albumArtist;
	NSString *title;
	NSInteger trackNumber;
	NSInteger trackCount;
	NSInteger discNumber;
	NSInteger discCount;
	NSUInteger artworkCount;
};
@interface Track : NSObject {
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
- (NSString *)title;
- (NSInteger)trackNumber;
- (NSInteger)trackCount;
- (NSInteger)discNumber;
- (NSInteger)discCount;
- (NSUInteger)artworkCount;
// you own the returned string
- (NSString *)formattedNumberTitleArtistAlbum;
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
- (id)initWithArtist:(NSString *)aa album:(NSString *)a;
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
- (void)setFirstArtwork:(NSImage *)a;
- (NSComparisonResult)compareForSortByArtist:(Album *)b;
- (NSComparisonResult)compareForSortByYear:(Album *)b;
- (NSComparisonResult)compareForSortByLength:(Album *)b;
@end
// makes and adds a new Album if not present; you must release the return value when done regardless
extern Album *albumInSet(NSMutableSet *albums, NSString *artist, NSString *album);

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
- (NSArray *)collectTracksAndAlbums:(NSSet **)albums withArtwork:(BOOL)withArtwork;
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
extern CFDataRef makePDF(NSArray *albums, BOOL onlyMinutes);

// regexp.m
// the code is the return from regcomp() and the localized description is already formatted with regerror(); there's currently no way to get preg out (TODO?)
extern NSString *const RegexpErrDomain;
@interface Regexp : NSObject {
	regex_t preg;
	BOOL valid;
}
// you own the returned error
- (id)initWithRegexp:(const char *)re caseInsensitive:(BOOL)caseInsensitive error:(NSError **)err;
- (BOOL)matches:(NSString *)str;
@end

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
