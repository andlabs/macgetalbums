// 25 september 2017
#import "macgetalbums.h"

#define pageWidth 612.0
#define pageHeight 792.0
#define margins 72.0
// TODO rename this to albumWidth?
#define itemWidth 108.0
#define padding 18.0
#define artworkTextPadding 4.5

// TODO save the text matrix
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
	// PDF contexts, like other Core Graphics contexts, are flipped
	// NSLayoutManager expects to draw in a flipped context (otherwise lines flow in reverse order)
	// so let's make NSGraphicsContext think our context is a genuine flipped context
	// this *should* be safe...
	// thanks to/see also:
	// - bayoubengal in irc.freenode.net #macdev
	// - https://stackoverflow.com/questions/6404057/create-pdf-in-objective-c
	// - https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html (moreso the note about iOS but it applies here too)
	CGContextTranslateCTM(c, 0, pageHeight);
	CGContextScaleCTM(c, 1.0, -1.0);
	// and do this too just to be safe
	CGContextSetTextMatrix(c, CGAffineTransformIdentity);
	new = [NSGraphicsContext graphicsContextWithGraphicsPort:c flipped:YES];
	[new retain];
	[NSGraphicsContext setCurrentContext:new];
	[new saveGraphicsState];
	return new;
}

static void endPageContext(CGContextRef c, NSGraphicsContext *nc, NSGraphicsContext *prev)
{
	[nc restoreGraphicsState];
	[NSGraphicsContext setCurrentContext:prev];
	if (prev != nil) {
		[prev restoreGraphicsState];
		[prev release];
	}
	[nc release];
	// this resets the CTM flipping done with mkPageContext()
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

// you own the returned image
static NSImage *compressImage(NSImage *artwork)
{
	NSNumber *quality;
	NSDictionary *props;
	NSData *compressedData;

	// If we don't do this, the PDFs can wind up with huge sizes, even with PNG!
	// Fortunately, CGPDFContext will preserve image compression for JPEGs and PNGs if specified, allowing this to work at all (see also https://lists.apple.com/archives/quartz-dev/2004/Nov/threads.html#00030, in particular the thread starting with https://lists.apple.com/archives/quartz-dev/2004/Nov/msg00025.html).
	// I'm fortunate NSImage operates similarly.
	// TODO fine-tune the quality
#define jpegQuality 0.85
	quality = [[NSNumber alloc] initWithDouble:jpegQuality];
	props = [[NSDictionary alloc] initWithObjectsAndKeys:quality, NSImageCompressionFactor, nil];
	[quality release];
	compressedData = [NSBitmapImageRep representationOfImageRepsInArray:[artwork representations]
		usingType:NSJPEGFileType
		properties:props];
	[props release];
	// TODO do we own compressedData?
	return [[NSImage alloc] initWithData:compressedData];
}

// you do NOT own the returned size
static NSValue *scaleImageSize(NSImage *artwork, CGFloat width)
{
	NSSize asize, bsize;

	asize = [artwork size];
	bsize.width = width;
	bsize.height = (asize.height * bsize.width) / asize.width;
	return [NSValue valueWithSize:bsize];
}

CFDataRef makePDF(NSArray *albums, BOOL onlyMinutes)
{
	CFMutableDataRef data;
	CGDataConsumerRef consumer;
	CGRect mediaBox;
	CGContextRef c;
	NSGraphicsContext *nc, *prev;
	NSFont *titleFont, *artistFont, *infoFont;
	NSColor *titleColor, *artistColor, *infoColor;
	CGFloat x, y;
	NSUInteger i, nPerLine;

	data = CFDataCreateMutable(NULL, 0);
	if (data == NULL) {
		// TODO produce an error
		return NULL;
	}
	consumer = CGDataConsumerCreateWithCFData(data);
	// consumer will retain data, according to the Programming Quartz book code samples
	mediaBox = CGRectMake(0, 0, pageWidth, pageHeight);
	c = CGPDFContextCreate(consumer, &mediaBox, NULL);
	if (c == NULL) {
		// TODO produce an error
		CGDataConsumerRelease(consumer);
		CFRelease(data);
		return NULL;
	}

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

	nPerLine = 1;
	// TODO make this logic clear somehow
	for (;;) {
		CGFloat items;
		CGFloat paddings;

		items = itemWidth * (CGFloat) nPerLine;
		paddings = padding * (CGFloat) (nPerLine - 1);
		if ((margins + items + padding) >= (pageWidth - margins - itemWidth))
			break;
		nPerLine++;
	}

	CGContextSaveGState(c);
	i = 0;
	nc = nil;
	while (i < [albums count]) {
		NSRange range;
		NSArray *line;
		CGFloat lineHeight;
		CGFloat maxArtworkHeight, maxTextHeight;
		NSMutableArray *compressedArtworks, *scaledSizes;
		NSMutableArray *titleCSLs, *artistCSLs, *infoCSLs;
		NSUInteger j;

		// get this line's albums
		range.location = i;
		range.length = nPerLine;
		if ((range.location + range.length) >= [albums count])
			range.length = [albums count] - range.location;
		line = [albums subarrayWithRange:range];
		// TODO switch to an autorelease pool
		[line retain];

		compressedArtworks = [[NSMutableArray alloc] initWithCapacity:[line count]];
		scaledSizes = [[NSMutableArray alloc] initWithCapacity:[line count]];
		titleCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		artistCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		infoCSLs = [[NSMutableArray alloc] initWithCapacity:[line count]];
		for (Album *a in line) {
			CSL *csl;
			NSMutableString *infostr;
			NSString *s;

			if ([a firstArtwork] == nil) {
				[compressedArtworks addObject:[NSNull null]];
				[scaledSizes addObject:[NSNull null]];
			} else {
				NSImage *compressed;

				compressed = compressImage([a firstArtwork]);
				[compressedArtworks addObject:compressed];
				[compressed release];
				[scaledSizes addObject:scaleImageSize([a firstArtwork], itemWidth)];
			}
			csl = [[CSL alloc] initWithText:[a album]
				width:itemWidth
				// TODO change all these titleThings to albumThings
				font:titleFont
				color:titleColor];
			[titleCSLs addObject:csl];
			[csl release];
			csl = [[CSL alloc] initWithText:[a artist]
				width:itemWidth
				font:artistFont
				color:artistColor];
			[artistCSLs addObject:csl];
			[csl release];
			infostr = [NSMutableString new];
			[infostr appendFormat:@"%ld", (long) [a year]];
			[infostr appendString:@" • "];
			// TODO song and disc count
			[infostr appendString:@" • "];
			s = [[a length] stringWithOnlyMinutes:onlyMinutes];
			[infostr appendString:s];
			[s release];
			csl = [[CSL alloc] initWithText:infostr
				width:itemWidth
				font:infoFont
				color:infoColor];
			[infoCSLs addObject:csl];
			[csl release];
			[infostr release];
		}

		// figure out how much vertical space we need
		maxArtworkHeight = 0;
		for (j = 0; j < [line count]; j++) {
			id obj;
			NSValue *v;
			CGFloat height;

			// make the no-artwork space square
			height = itemWidth;
			obj = [scaledSizes objectAtIndex:j];
			if (obj != [NSNull null]) {
				v = (NSValue *) obj;
				height = [v sizeValue].height;
			}
			if (maxArtworkHeight < height)
				maxArtworkHeight = height;
		}
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
		if (nc != nil && (y + lineHeight) >= (pageHeight - margins)) {
			endPageContext(c, nc, prev);
			nc = nil;
			prev = nil;
		}
		if (nc == nil) {
			nc = mkPageContext(c, &prev);
			y = margins;
		}

		// lay out the artworks
		x = margins;
		for (j = 0; j < [line count]; j++) {
			id obj;
			NSImage *img;
			NSValue *v;
			NSRect r;

			r.origin.x = x;
			r.origin.y = y;
			obj = [compressedArtworks objectAtIndex:j];
			if (obj == [NSNull null])
				/* TODO draw a default image here */;
			else {
				img = (NSImage *) obj;
				v = (NSValue *) [scaledSizes objectAtIndex:j];
				r.size = [v sizeValue];
				[img drawInRect:r];
			}
			x += itemWidth + padding;
		}
		y += maxArtworkHeight;

		y += artworkTextPadding;

		// lay out the texts
		x = margins;
		for (j = 0; j < [line count]; j++) {
			CSL *csl;
			CGFloat cy;

			csl = (CSL *) [titleCSLs objectAtIndex:j];
			cy = y;
			[csl drawAt:NSMakePoint(x, cy)];
			cy += [csl height];
			csl = (CSL *) [artistCSLs objectAtIndex:j];
			[csl drawAt:NSMakePoint(x, cy)];
			cy += [csl height];
			csl = (CSL *) [infoCSLs objectAtIndex:j];
			[csl drawAt:NSMakePoint(x, cy)];
			cy += [csl height];
			x += itemWidth + padding;
		}
		y += maxTextHeight;

		y += padding;
		i += [line count];

		[infoCSLs release];
		[artistCSLs release];
		[titleCSLs release];
		[scaledSizes release];
		[compressedArtworks release];
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

	CGPDFContextClose(c);
	CGContextRelease(c);
	CGDataConsumerRelease(consumer);
	return data;
}
