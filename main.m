// 8 june 2017
#import "macgetalbums.h"

// TODO consider MediaLibrary? (thanks mattstevens in irc.freenode.net #macdev)

BOOL verbose = NO;
BOOL showLengths = NO;

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
	NSArray *tracks;
	double duration;
	Timer *timer;
	int c;

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

	tracks = collectTracks(&duration);
	if (verbose)
		printf("time to issue script: %gs\n", duration);

	albums = [NSMutableSet new];
	timer = [Timer new];
	[timer start];
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
			if (existing.Year > track.Year)
				existing.Year = track.Year;
			existing.Length += track.Length;
			continue;
		}
		[albums addObject:track];
	}
	[timer end];
	if (verbose)
		printf("time to process tracks: %gs\n", [timer seconds]);
	[timer release];
	[tracks release];

	if (verbose)
		printf("album count: %lu\n",
			(unsigned long) [albums count]);
	// TODO is tab safe to use?
	// TODO switch to foreach
	[albums enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		Item *t = (Item *) obj;

		printf("%ld\t%s\t%s",
			(long) (t.Year),
			[t.Artist UTF8String],
			[t.Album UTF8String]);
		if (showLengths)
			printf("\t%s",
				[[t lengthString] UTF8String]);
		printf("\n");
	}];

	// TODO clean up?
	return 0;
}
