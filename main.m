// 8 june 2017
#import "macgetalbums.h"

// TODO prefix these with opt?
// TODO change verbose to debug and switch from using printf
BOOL verbose = NO;
BOOL showLengths = NO;
// TODO option to show counts
// TODO option to force a specific collector

// TODO why can't this be const?
static NSString *collectors[] = {
	@"iTunesLibraryCollector",
	@"ScriptingBridgeCollector",
	nil,
};

NSMutableSet *albums = nil;

const char *argv0;

void usage(void)
{
	fprintf(stderr, "usage: %s [-hlv]\n", argv0);
	fprintf(stderr, "  -h - show this help\n");
	fprintf(stderr, "  -l - show album lengths\n");
	fprintf(stderr, "  -v - print verbose output\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	id<Collector> collector;
	Class<Collector> collectorClass;
	NSArray *tracks;
	Timer *timer;
	NSError *err = nil;
	BOOL signCheckSucceeded;
	int i, c;

	argv0 = argv[0];
	while ((c = getopt(argc, argv, ":hlv")) != -1)
		switch (c) {
		case 'v':
			// TODO rename to -d for debug?
			verbose = YES;
			break;
		case 'l':
			showLengths = YES;
			break;
		case '?':
			fprintf(stderr, "error: unknown option -%c\n", optopt);
			// fall through
		case 'h':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;
	if (argc != 0)
		usage();

	signCheckSucceeded = checkIfSigned();
	if (verbose) {
		if (!signCheckSucceeded)
			printf("signed-code checking failed with error %d; assuming not signed\n", (int) amISignedErr);
		else if (amISigned)
			printf("we are signed\n");
		else
			printf("we are not signed\n");
	}

	timer = [Timer new];

	collector = nil;
	for (i = 0; collectors[i] != nil; i++) {
		collectorClass = NSClassFromString(collectors[i]);
		if (verbose)
			printf("trying collector %s\n",
				[[collectorClass collectorName] UTF8String]);
		// TODO signing
		collector = [[collectorClass alloc] initWithTimer:timer error:&err];
		if (err != nil) {
			if (verbose)
				printf("error using collector %s: %s; skipping\n",
					[[collectorClass collectorName] UTF8String],
					[[err description] UTF8String]);
			// TODO release err?
			[collector release];
			collector = nil;
			continue;
		}
		if (verbose)
			printf("time to load iTunes library: %gs\n", [timer seconds:TimerLoad]);
		break;
	}
	if (collector == nil) {
		fprintf(stderr, "error: no iTunes collector could be used; cannot continue\n");
		return 1;
	}

	tracks = [collector collectTracks];
	if (verbose)
		printf("time to collect tracks: %gs\n", [timer seconds:TimerCollect]);

	albums = [NSMutableSet new];
	[timer start:TimerSort];
	if (verbose)
		// TODO with Scripting Bridge this is ~1e-5 seconds?! should we include the SBApplication constructor?
		printf("track count: %ld\n", (long) [tracks count]);
	for (Item *track in tracks) {
		Item *existing;

		// If the album is already in the set, update the year and
		// the length; otherwise, just add the track to start off this
		// new album (effectively turning a track Item into an
		// album Item).
		existing = (Item *) [albums member:track];
		if (existing != nil) {
			// We want to take the earliest release date, to
			// reflect the original release of this album.
			if ([existing year] > [track year])
				[existing setYear:[track year]];
			[[existing length] add:[track length]];
			continue;
		}
		[albums addObject:track];
	}
	[timer end];
	if (verbose)
		printf("time to process tracks: %gs\n", [timer seconds:TimerSort]);
	[tracks release];
	[collector release];
	[timer release];

	if (verbose)
		printf("album count: %lu\n",
			(unsigned long) [albums count]);
	// TODO is tab safe to use?
	// TODO switch to foreach
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		Item *t = (Item *) obj;

		printf("%ld\t%s\t%s",
			(long) ([t year]),
			[[t artist] UTF8String],
			[[t album] UTF8String]);
		if (showLengths)
			printf("\t%s",
				[[[t length] description] UTF8String]);
		printf("\n");
	}];

	// TODO clean up here?
	return 0;
}
