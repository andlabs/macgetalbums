// 7 august 2017
// TODO move file-specific headers out of here
#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
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
extern NSInteger handleOverrides(NSInteger year, NSString *artist, NSString *album);
