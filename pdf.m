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

// based on https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html#//apple_ref/doc/uid/20001809-CJBGBIBB
@interface CSL : NSObject {
	NSLayoutManager *l;
	NSTextStorage *s;
	NSTextContainer *c;
	NSRange textRange;
	NSRange glyphRange;
}
- (id)initWithText:(NSString *)text width:(CGFloat)width font:(NSFont *)font color:(NSColor *)color;
- (CGFloat)height;
- (void)drawAt:(NSPoint)p;
@end

@implementation CSL

- (id)initWithText:(NSString *)text width:(CGFloat)width font:(NSFont *)font color:(NSColor *)color
{
	NSRange textRange;

	self = [super init];
	if (self) {
		self->s = [[NSTextStorage alloc] initWithString:text];
		self->c = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, CGFLOAT_MAX)];
		self->l = [NSLayoutManager new];

		[self->l addTextContainer:self->c];
		[self->s addLayoutManager:self->l];

		self->textRange.location = 0;
		self->textRange.length = [s length];
		[self->s addAttribute:NSFontAttributeName
			value:font
			range:self->textRange];
		[self->s addAttribute:NSForegroundColorAttributeName
			value:color
			range:self->textRange];
		[self->c setLineFragmentPadding:0];

		self->glyphRange = [self->l glyphRangeForTextContainer:self->c];
	}
	return self;
}

- (void)dealloc
{
	[self->l release];
	[self->s release];
	[self->c release];
	[super dealloc];
}

- (CGFloat)height
{
	return [self->l usedRectForTextContainer:self->c].size.height;
}

- (void)drawAt:(NSPoint)p
{
	[self->l drawGlyphsForGlyphRange:self->glyphRange atPoint:p];
}

@end

CFDataRef makePDF(NSSet *albums, BOOL onlyMinutes)
{
	CFMutableDataRef data;
	CGDataConsumerRef consumer;
	CGSize mediaBox;
	CGContextRef c;
	NSGraphicsContext *nc, *prev;
	NSArray *albumsarr;
	NSFont *titleFont, *artistFont, *infoFont;
	NSColor *titleColor, *artistColor, *infoColor;
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
	// TODO switch to an autorelease pool
	[albumsarr retain];

	// TODO switch to an autorelease pool
	titleFont = [NSFont boldSystemFontOfSize:12];
	[titleFont retain];
	titleColor = [NSColor blackColor];
	[titleColor retain];
	artistFont = [NSFont systemFontOfSize:12];
	[artistFont retain];
	artistColor = [NSColor blackColor];
	[artistColor retain];
	infoFont = [NSFont systemFontOfSize:11];
	[infoFont retain];
	infoColor = [NSColor darkGrayColor];
	[infoColor retain];

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
		NSMutableArray *titleCSLs, *artistCSLs, *infoCSLs;
		NSUInteger j;

		// get this line's albums
		range.location = i;
		range.length = nPerLine;
		if ((range.location + range.length) >= [albums count])
			range.length = [albums count] - range.location;
		line = [albumsArr subarrayWithRange:range];
		// TODO switch to an autorelease pool
		[line retain];

		titleCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		artistCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		infoCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		for (Item *a in line) {
			CSL *csl;
			NSMutableString *infostr;
			NSString *s;

			csl = [[CSL alloc] initWithString:[a album]
				width:itemWidth
				// TODO change all these titleThings to albumThings
				font:titleFont
				color:titleColor];
			[titleCSLs addObject:csl];
			[csl release];
			csl = [[CSL alloc] initWithString:[a artist]
				width:itemWidth
				font:artistFont
				color:artistColor];
			[artistCSLs addObject:csl];
			[csl release];
			infostr = [NSMutableString new];
			[infostr appendFormat:@"%ld", (long) [a year]];
			[infostr appendString:@" • "];
			xx TODO song and disc count
			[infostr appendString:@" • "];
			s = [[a length] stringWithOnlyMinutes:onlyMinutes];
			[infostr appendString:s];
			[s release];
			csl = [[TextContainerStorageLayout alloc] initWithString:infostr
				width:itemWidth
				font:infoFont
				color:infoColor];
			[infoCSLs addObject:csl];
			[csl release];
			[infostr release];
		}

		// figure out how much vertical space we need
		maxArtworkHeight = 0;
		// TODO
		maxTextHeight = 0;
		for (j = 0; j < [line count]; j++) {
			CSL *csl;
			CGFloat h;

			csl = (CSL *) [titleCSLs objectAtIndex:j];
			h = [csl height];
			// TODO any extra padding maybe
			csl = (CSL *) [artistCSLs objectAtIndex:j];
			h += [csl height];
			csl = (CSL *) [infoCSLs objectAtIndex:j];
			h += [csl height];
			if (maxTextHeight <= h)
				maxTextHeight = h;
		}
		lineHeight = maxArtworkHeight + artworkTextPadding + maxTextHeight;

		// set up a page if needed
		if (nc != nil && (y - lineHeight) <= margins) {
			endPageContext(c, nc, prev);
			nc = nil;
			prev = nil;
		}
		if (nc == nil) {
			nc = mkPageContext(c, &prev);
			y = pageHeight - margins;
		}

		// TODO lay out the artworks
		y -= maxArtworkHeight;

		y -= artworkTextPadding;

		// lay out the texts
		x = margins;
		for (j = 0; j < [line length]; j++) {
			CSL *csl;
			CGFloat cy;

			csl = (CSL *) [titleCSLs objectAtIndex:j];
			cy = y - [csl height];
			[csl drawAt:NSMakePoint(x, cy)];
			csl = (CSL *) [artistCSLs objectAtIndex:j];
			cy -= [csl height];
			[csl drawAt:NSMakePoint(x, cy)];
			csl = (CSL *) [infoCSLs objectAtIndex:j];
			cy -= [csl height];
			[csl drawAt:NSMakePoint(x, cy)];
			x += itemWidth + padding;
		}
		y -= maxTextHeight;

		y -= padding;

		[infoCSLs release];
		[artworkCSLs release];
		[titleCSLs release];
		[line release];
	}
	if (nc != nil) {
		endPageContext(c, nc, prev);
		nc = nil;
		prev = nil;
	}
	CGContextRestoreGState(c);

	[infoColor release];
	[infoFont release];
	[artistColor release];
	[artistFont release];
	[titleColor release];
	[titleFont release];

	[albumsarr release];

	CGPDFContextClose(c);
	CGContextRelease(c);
	CGDataConsumerRelease(consumer);
	return data;
}
