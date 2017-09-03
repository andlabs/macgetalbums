// 3 september 2017
#import <Foundation/Foundation.h>
#import <MediaLibrary/MediaLibrary.h>
#import <stdio.h>

@interface MediaLibraryObserver : NSObject {
	MLMediaLibrary *library;
	MLMediaSource *source;
	MLMediaGroup *group;
	int state;
}
- (BOOL)done;
@end

enum {
	stateCollectingSources,
	stateCollectingRootMediaGroup,
	stateCollectingTracks,
	stateDone,
};

@implementation MediaLibraryObserver

- (id)init
{
	self = [super init];
	if (self) {
		NSMutableDictionary *options;

		self->source = nil;

		options = [NSMutableDictionary new];
		[options setObject:[NSNumber numberWithUnsignedInteger:MLMediaSourceTypeAudio]
			forKey:MLMediaLoadSourceTypesKey];
		[options setObject:[NSArray arrayWithObject:MLMediaSourceiTunesIdentifier]
			forKey:MLMediaLoadIncludeSourcesKey];
		self->library = [[MLMediaLibrary alloc] initWithOptions:options];
		[self->library addObserver:self
			forKeyPath:@"mediaSources"
			options:NSKeyValueObservingOptionNew
			context:self];
		// this will return nil and trigger the collection
		[self->library mediaSources];
		self->state = stateCollectingSources;
		[options release];
	}
	return self;
}

- (void)dealloc
{
	if (self->group != nil) {
		[self->group removeObserver:self forKeyPath:@"mediaObjects"];
		[self->group release];
	}
	if (self->source != nil) {
		[self->source removeObserver:self forKeyPath:@"rootMediaGroup"];
		[self->source release];
	}
	[self->library removeObserver:self forKeyPath:@"mediaSources"];
	[self->library release];
	[super dealloc];
}

- (BOOL)shouldHandle:(NSString *)keyPath of:(id)object
{
	switch (self->state) {
	case stateCollectingSources:
		return object == self->library &&
			[keyPath isEqual:@"mediaSources"];
	case stateCollectingRootMediaGroup:
		return object == self->source &&
			[keyPath isEqual:@"rootMediaGroup"];
	case stateCollectingTracks:
		return object == self->group &&
			[keyPath isEqual:@"mediaObjects"];
	}
	return NO;
}

// TODO should we ensure the state is correct?
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context
{
	MLMediaSource *src;
	NSArray *tracks;

	if (![self shouldHandle:keyPath of:object]) {
		[super observeValueForKeyPath:keyPath
			ofObject:object
			change:change
			context:context];
		return;
	}
	switch (state) {
	case stateCollectingSources:
		NSLog(@"got a source");
		// a source came in; is it the one we want?
		src = [[self->library mediaSources] objectForKey:MLMediaSourceiTunesIdentifier];
		if (src == nil)		// nope
			break;
		NSLog(@"got THE source");
		// we have our source; now collect the root media group so we can get specific groups
		self->source = src;
		[self->source retain];
		[self->source addObserver:self
			forKeyPath:@"rootMediaGroup"
			options:NSKeyValueObservingOptionNew
			context:self];
		// this will return nil and trigger the collection
		[self->source rootMediaGroup];
		self->state = stateCollectingRootMediaGroup;
		break;
	case stateCollectingRootMediaGroup:
		NSLog(@"got the root media group");
		// TODO do we want the MLiTunesMusicPlaylistTypeIdentifier group instead? that depends on what the Scripting Bridge -[iTunesApplication tracks] method returns...
		self->group = [self->source rootMediaGroup];
		[self->group retain];
		[self->group addObserver:self
			forKeyPath:@"mediaObjects"
			options:NSKeyValueObservingOptionNew
			context:self];
		// this will return nil and trigger the collection
		[self->group mediaObjects];
		self->state = stateCollectingTracks;
		break;
	case stateCollectingTracks:
		NSLog(@"got our tracks");
		tracks = [self->group mediaObjects];
		NSLog(@"count: %lu", (unsigned long) [tracks count]);
		for (MLMediaObject *o in tracks)
//			NSLog(@"%@ %@ %@", [o name], [o modificationDate], [o attributes]);
			NSLog(@"%@ %@ %@ %@ %@",
				[o name],
				[o attributes][MLMediaObjectArtistKey],
				[o attributes][@"xxxx"],
				[o attributes][MLMediaObjectDurationKey],
				[o attributes][@"Year"]);
		self->state = stateDone;
	}
}

- (BOOL)done
{
	return self->state == stateDone;
}

@end

int main(void)
{
	MediaLibraryObserver *o;
	NSRunLoop *mainloop;

	o = [MediaLibraryObserver new];
	mainloop = [NSRunLoop mainRunLoop];
	NSLog(@"running main loop");
	while (![o done])
		if ([mainloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]] == NO)
		NSLog(@"run loop returned NO");
	NSLog(@"done\n");
	[o release];
	return 0;
}
