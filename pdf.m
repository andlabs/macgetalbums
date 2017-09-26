// 25 september 2017
#import "macgetalbums.h"

#define pageWidth 612
#define pageHeight 792
#define margins 72
#define itemWidth 108
#define padding 18
#define artworkTextPadding 4.5

static NSGraphicsContext *mkPageContext(CGContextRef c, NSGraphicsContext **prev)
{
	NSGraphicsContext *new;

	CGContextSaveGState(c);
	CGContextBeginPage(c, NULL);

	CGContextSaveGState(c);
	*prev = [NSGraphicsContext currentContext];
	if (*prev != nil) {
		[*prev saveGraphicsState];
		[*prev retain];
	}
	new = [NSGraphicsContext graphicsContextWithGraphicsPort:c flipped:NO];
	[new retain];
	[NSGraphicsContext setCurrentContext:new];
	[new saveGraphicsState];
	return new;
}

static void endPageContext(CGContextRef c, NSGraphicsContext *nc, NSGraphicsContext *prev)
{
	[nc restoreGraphicsState];
	[NSGraphicsContext setCurrnetContext:prev];
	if (prev != nil) {
		[prev restoreGraphicsState];
		[prev release];
	}
	[nc release];
	CGContextRestoreGState(c);

	CGContextEndPage(c);
	CGContextRestoreGState(c);
}

CFDataRef makePDF(NSSet *albums)
{
	CFMutableDataRef data;
	CGDataConsumerRef consumer;
	CGSize mediaBox;
	CGContextRef c;
	NSGraphicsContext *nc, *prev;
	NSArray *albumsarr;
	CGFloat x, y;
	NSUInteger i, nPerRow;

	data = CFDataCreateMutable(NULL, 0);
	if (data == NULL) {
		// TODO produce an error
		return NULL;
	}
	consumer = CGDataConsumerCreateWithCFData(data);
	// consumer will retain data, according to the Programming Quartz book code samples
	mediaBox = CGSizeMake(pageWidth, pageHeight);
	c = CGPDFContextCreate(consumer, &mediaBox, NULL);
	if (c == NULL) {
		// TODO produce an error
		CGDataConsumerRelease(consumer);
		CFRelease(data);
		return NULL;
	}

	albumsarr = [albums allObjects];
	xx TODO switch to an autorelease pool
	[albumsarr retain];

	nPerRow = 1;
	for (;;) {
		CGFloat items;
		CGFloat paddings;
		CGFloat width;

		items = itemWidth * (CGFloat) nPerLine;
		paddings = padding * (CGFloat) (nPerLine - 1);
		width = pageWidth - margins - margins;
		if ((items + padding) > width)
			break;
		nPerLine++;
	}

	CGContextSaveGState(c);
	i = 0;
	while (i < [albums count]) {
		NSRange range;
		NSArray *line;
		CGFloat lineHeight;
		CGFloat maxArtworkHeight, maxTextHeight;

		xx get this line's albums
		range.location = i;
		range.length = nPerLine;
		if ((range.location + range.length) >= [albums count])
			range.length = [albums count] - range.location;
		line = [albumsArr subarrayWithRange:range];
		xx TODO switch to an autorelease pool
		[line retain];

		xx figure out how much vertical space we need
		maxArtworkHeight = 0;
		xx TODO
		maxTextHeight = 0;
		xx TODO
		lineHeight = maxArtworkHeight + artworkTextPadding + maxTextHeight;

		xx set up a page if needed
		if (nc != nil && (y - lineHeight) <= margins) {
			endPageContext(c, nc, prev);
			nc = nil;
			prev = nil;
		}
		if (nc == nil) {
			nc = mkPageContext(c, &prev);
			x = margins;
			y = pageHeight - margins;
		}

		xx TODO lay out the line

		[line release];
	}
	if (nc != nil) {
		endPageContext(c, nc, prev);
		nc = nil;
		prev = nil;
	}
	CGContextRestoreGState(c);

	[albumsarr release];

	CGPDFContextClose(c);
	CGContextRelease(c);
	CGDataConsumerRelease(consumer);
	return data;
}
