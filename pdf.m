// 25 september 2017
#import "macgetalbums.h"

#define artworkTextPadding 4.5

// TODO allocate and own data ourself?
@interface pdfContext : NSObject {
	CGDataConsumerRef dataConsumer;
	CGContextRef c;
	CGFloat pageHeight;
	NSGraphicsContext *prev;
	NSGraphicsContext *cur;
}
- (id)initWithTarget:(CFMutableDataRef)data pageWidth:(CGFloat)pw pageHeight:(CGFloat)ph;
- (void)beginPage;
- (void)endPage;
- (void)end;
@end

@implementation pdfContext

- (id)initWithTarget:(CFMutableDataRef)data pageWidth:(CGFloat)pw pageHeight:(CGFloat)ph
{
	self = [super init];
	if (self) {
		CGRect mediaBox;

		self->c = NULL;
		self->pageHeight = ph;
		self->prev = nil;
		self->cur = nil;

		self->dataConsumer = CGDataConsumerCreateWithCFData(data);
		// self->dataConsumer will retain data, according to the Programming Quartz book code samples
		mediaBox = CGRectMake(0, 0, pw, self->pageHeight);
		self->c = CGPDFContextCreate(self->dataConsumer, &mediaBox, NULL);
		if (self->c == NULL) {
			// TODO produce an error
			CGDataConsumerRelease(self->dataConsumer);
			self->dataConsumer = NULL;
			goto out;
		}
		CGContextSaveGState(self->c);
	}
out:
	return self;
}

// TODO throw exceptions instead of silently fixing broken stuff

- (void)dealloc
{
	// TODO throw an exception if self->c is not NULL
	[super dealloc];
}

// TODO save the text matrix
- (void)beginPage
{
	if (self->cur != nil)
		[self endPage];

	CGContextSaveGState(self->c);
	CGContextBeginPage(self->c, NULL);

	CGContextSaveGState(self->c);
	self->prev = [NSGraphicsContext currentContext];
	if (self->prev != nil) {
		[self->prev saveGraphicsState];
		[self->prev retain];
	}

	// PDF contexts, like other Core Graphics contexts, are flipped
	// NSLayoutManager expects to draw in a flipped context (otherwise lines flow in reverse order)
	// so let's make NSGraphicsContext think our context is a genuine flipped context
	// this *should* be safe...
	// thanks to/see also:
	// - bayoubengal in irc.freenode.net #macdev
	// - https://stackoverflow.com/questions/6404057/create-pdf-in-objective-c
	// - https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html (moreso the note about iOS but it applies here too)
	CGContextTranslateCTM(self->c, 0, self->pageHeight);
	CGContextScaleCTM(self->c, 1.0, -1.0);
	// and do this too just to be safe
	CGContextSetTextMatrix(self->c, CGAffineTransformIdentity);

	self->cur = [NSGraphicsContext graphicsContextWithGraphicsPort:self->c flipped:YES];
	[self->cur retain];
	[NSGraphicsContext setCurrentContext:self->cur];
	[self->cur saveGraphicsState];
}

- (void)endPage
{
	if (self->cur == nil)
		/* TODO throw exception as above */;

	[self->cur restoreGraphicsState];
	[NSGraphicsContext setCurrentContext:self->prev];
	if (self->prev != nil) {
		[self->prev restoreGraphicsState];
		[self->prev release];
		self->prev = nil;
	}
	[self->cur release];
	self->cur = nil;
	// this resets the CTM flipping done in -beginPage above
	CGContextRestoreGState(self->c);

	CGContextEndPage(self->c);
	CGContextRestoreGState(self->c);
}

- (void)end
{
	if (self->cur != nil)
		/* TODO throw exception as above */;

	CGContextRestoreGState(self->c);
	CGPDFContextClose(self->c);
	CGContextRelease(self->c);
	self->c = NULL;
	CGDataConsumerRelease(self->dataConsumer);
	self->dataConsumer = NULL;
}

@end

// based on https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html#//apple_ref/doc/uid/20001809-CJBGBIBB and https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/TextLayout/Tasks/DrawingStrings.html#//apple_ref/doc/uid/20001808-SW4
@interface CSL : NSObject {
	NSLayoutManager *l;
	NSTextStorage *s;
	NSTextContainer *c;
	NSRange textRange;
	NSRange glyphRange;
}
- (id)initWithText:(NSString *)text width:(CGFloat)width font:(NSFont *)font color:(NSColor *)color;
- (CGFloat)height;
- (void)drawAtPoint:(NSPoint)p;
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

- (void)drawAtPoint:(NSPoint)p
{
	[self->l drawGlyphsForGlyphRange:self->glyphRange atPoint:p];
}

@end

@interface pdfFontSet : NSObject {
	NSFont *albumFont;
	NSColor *albumColor;
	NSFont *artistFont;
	NSColor *artistColor;
	NSFont *infoFont;
	NSColor *infoColor;
}
- (id)initWithFamily:(const char *)family;
- (NSFont *)albumFont;
- (NSColor *)albumColor;
- (NSFont *)artistFont;
- (NSColor *)artistColor;
- (NSFont *)infoFont;
- (NSColor *)infoColor;
@end

@implementation pdfFontSet

- (id)initWithFamily:(const char *)family
{
	self = [super init];
	if (self)
		@autoreleasepool {
			self->albumFont = [NSFont boldSystemFontOfSize:12];
			self->albumColor = [NSColor blackColor];
			self->artistFont = [NSFont systemFontOfSize:12];
			self->artistColor = [NSColor blackColor];
			self->infoFont = [NSFont systemFontOfSize:11];
			self->infoColor = [NSColor darkGrayColor];

			if (family != NULL) {
				NSString *name;
				NSFontDescriptor *fontdesc;

				name = [NSString stringWithUTF8String:family];
				fontdesc = [NSFontDescriptor fontDescriptorWithFontAttributes:nil];
				fontdesc = [fontdesc fontDescriptorWithFamily:name];
				self->albumFont = [NSFont fontWithDescriptor:[fontdesc fontDescriptorWithSymbolicTraits:NSFontBoldTrait] size:12];
				self->artistFont = [NSFont fontWithDescriptor:fontdesc size:12];
				self->infoFont = [NSFont fontWithDescriptor:fontdesc size:11];
			}

			[self->albumFont retain];
			[self->albumColor retain];
			[self->artistFont retain];
			[self->artistColor retain];
			[self->infoFont retain];
			[self->infoColor retain];
		}
	return self;
}

- (void)dealloc
{
	[self->infoColor release];
	[self->infoFont release];
	[self->artistColor release];
	[self->artistFont release];
	[self->albumColor release];
	[self->albumFont release];
	[super dealloc];
}

- (NSFont *)albumFont
{
	return self->albumFont;
}

- (NSColor *)albumColor
{
	return self->albumColor;
}

- (NSFont *)artistFont
{
	return self->artistFont;
}

- (NSColor *)artistColor
{
	return self->artistColor;
}

- (NSFont *)infoFont
{
	return self->infoFont;
}

- (NSColor *)infoColor
{
	return self->infoColor;
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
	// TODO fine-tune the quality; make it a parameter (both to help fine-tune it and in case an override is necessary)
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

// these are what iTunes v12.7.0.166 uses to decide if an album art is "square enough" or not
static uint64_t itSquareMinRatioBits = 0x3FECCCCCC0000000;		// ~0.900000
static double itSquareMinRatio;
static uint64_t itSquareMaxRatioBits = 0x3FF1C71C79ADD3C4;		// ~1.111111
static double itSquareMaxRatio;
static BOOL itSquaresLoaded = NO;

// this implementation avoids strict aliasing issues (thanks GerbilSoft)
static double float64frombits(uint64_t u)
{
	union {
		uint64_t u;
		double d;
	} x;

	x.u = u;
	return x.d;
}

static BOOL isSquareEnough(NSSize size)
{
	CGFloat cgratio;
	double ratio;

	if (!itSquaresLoaded) {
		itSquaresLoaded = YES;
		itSquareMinRatio = float64frombits(itSquareMinRatioBits);
		itSquareMaxRatio = float64frombits(itSquareMaxRatioBits);
	}
	cgratio = size.width / size.height;
	ratio = (double) cgratio;
	return (ratio >= itSquareMinRatio) && (ratio < itSquareMaxRatio);
}

static CGFloat scaleHeight(NSSize orig, CGFloat newWidth)
{
	return (orig.height * newWidth) / orig.width;
}

static NSString *albumInfoString(Album *a, BOOL minutesOnly)
{
	NSMutableString *infostr;
	NSString *s;

	infostr = [NSMutableString new];
	[infostr appendFormat:@"%ld", (long) [a year]];
	[infostr appendString:@" • "];
	// TODO song and disc count
	[infostr appendString:@" • "];
	s = [[a length] stringWithOnlyMinutes:minutesOnly];
	[infostr appendString:s];
	[s release];
	return infostr;
}

@interface pdfAlbumItem : NSObject {
	CGFloat width;
	NSImage *compressedImage;
	CGFloat scaledImageHeight;
	CSL *albumCSL;
	CSL *artistCSL;
	CSL *infoCSL;
}
- (id)initWithAlbum:(Album *)a width:(CGFloat)wid minutesOnly:(BOOL)minutesOnly fontSet:(pdfFontSet *)fs;
- (CGFloat)scaledImageHeight;
- (CGFloat)totalTextHeight;
- (void)drawAtPoint:(NSPoint)pt withMaxArtworkHeight:(CGFloat)artHeight;
@end

@implementation pdfAlbumItem

- (id)initWithAlbum:(Album *)a width:(CGFloat)wid minutesOnly:(BOOL)minutesOnly fontSet:(pdfFontSet *)fs
{
	self = [super init];
	if (self) {
		NSString *infostr;

		self->width = wid;

		self->compressedImage = nil;
		// TODO rename scaledArtworkHeight maybe, and other such cases (like maxImageHeight)
		self->scaledImageHeight = self->width;
		if ([a firstArtwork] != nil) {
			NSSize size;

			self->compressedImage = compressImage([a firstArtwork]);
			// TODO make this an option
			size = [self->compressedImage size];
			if (isSquareEnough(size))
				self->scaledImageHeight = self->width;
			else
				self->scaledImageHeight = scaleHeight([self->compressedImage size], self->width);
		}

		self->albumCSL = [[CSL alloc] initWithText:[a album]
			width:self->width
			font:[fs albumFont]
			color:[fs albumColor]];
		self->artistCSL = [[CSL alloc] initWithText:[a artist]
			width:self->width
			font:[fs artistFont]
			color:[fs artistColor]];
		infostr = albumInfoString(a, minutesOnly);
		self->infoCSL = [[CSL alloc] initWithText:infostr
			width:self->width
			font:[fs infoFont]
			color:[fs infoColor]];
		[infostr release];
	}
	return self;
}

- (void)dealloc
{
	[self->infoCSL release];
	[self->albumCSL release];
	[self->artistCSL release];
	if (self->compressedImage != nil)
		[self->compressedImage release];
	[super dealloc];
}

- (CGFloat)scaledImageHeight
{
	return self->scaledImageHeight;
}

- (CGFloat)totalTextHeight
{
	// TODO any extra padding maybe?
	return [self->albumCSL height] +
		[self->artistCSL height] +
		[self->infoCSL height];
}

// TODO should an entire row's worth of art be drawn first, then an entire's row of text, and so on? that's how we used to do it before this class existed

// TODO find a better name for the second part of this selector and its argument
- (void)drawAtPoint:(NSPoint)pt withMaxArtworkHeight:(CGFloat)artHeight
{
	// first draw artwork
	// the artwork will be bottom-aligned vertically
	if (self->compressedImage == nil)
		/* TODO draw a default image here */;
	else {
		NSRect r;

		r.origin = pt;
		r.origin.y += (artHeight - self->scaledImageHeight);
		r.size.width = self->width;
		r.size.height = self->scaledImageHeight;
		[self->compressedImage drawInRect:r];
	}

	pt.y += artHeight;
	pt.y += artworkTextPadding;

	// now draw text
	[self->albumCSL drawAtPoint:pt];
	pt.y += [self->albumCSL height];
	[self->artistCSL drawAtPoint:pt];
	pt.y += [self->artistCSL height];
	[self->infoCSL drawAtPoint:pt];
}

@end

CFDataRef makePDF(NSArray *albums, struct makePDFParams *p)
{
	CFMutableDataRef data;
	pdfContext *c;
	NSMutableArray *albumItems;
	pdfFontSet *fs;
	CGFloat x, y;
	CGFloat maxImageHeight, maxTextHeight;
	CGFloat lineHeight;
	BOOL inPage;

	data = CFDataCreateMutable(NULL, 0);
	if (data == NULL) {
		// TODO produce an error
		return NULL;
	}
	c = [[pdfContext alloc] initWithTarget:data
		pageWidth:p->pageWidth
		pageHeight:p->pageHeight];

	fs = [[pdfFontSet alloc] initWithFamily:p->fontFamily];
	albumItems = [[NSMutableArray alloc] initWithCapacity:[albums count]];
	maxImageHeight = 0;
	maxTextHeight = 0;
	for (Album *a in albums) {
		pdfAlbumItem *item;

		item = [[pdfAlbumItem alloc] initWithAlbum:a
			width:p->itemWidth
			minutesOnly:p->minutesOnly
			fontSet:fs];
		if (maxImageHeight < [item scaledImageHeight])
			maxImageHeight = [item scaledImageHeight];
		if (maxTextHeight < [item totalTextHeight])
			maxTextHeight = [item totalTextHeight];
		[albumItems addObject:item];
		[item release];
	}
	lineHeight = maxImageHeight + artworkTextPadding + maxTextHeight;

	inPage = NO;
	for (pdfAlbumItem *item in albumItems) {
		// set up a page if needed
		if (inPage && (y + lineHeight) >= (p->pageHeight - p->margins)) {
			[c endPage];
			inPage = NO;
		}
		if (!inPage) {
			inPage = YES;
			[c beginPage];
			x = p->margins;
			y = p->margins;
			if (p->debugLayout) {
				[NSGraphicsContext saveGraphicsState];
				@autoreleasepool {
					NSBezierPath *path;
					CGFloat ly;

					[[NSColor grayColor] set];
					ly = y;
					path = [NSBezierPath bezierPath];
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += maxImageHeight;
					path = [NSBezierPath bezierPath];
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += artworkTextPadding;
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += maxTextHeight;
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
				}
				[NSGraphicsContext restoreGraphicsState];
			}
		}

		[item drawAtPoint:NSMakePoint(x, y)
			withMaxArtworkHeight:maxImageHeight];
		x += p->itemWidth;

		x += p->padding;
		// move to the next line if needed
		if ((x + p->itemWidth) >= (p->pageWidth - p->margins)) {
			x = p->margins;
			y += lineHeight;
			y += p->padding;
			if (p->debugLayout) {
				// TODO deduplicate
				[NSGraphicsContext saveGraphicsState];
				@autoreleasepool {
					NSBezierPath *path;
					CGFloat ly;

					[[NSColor grayColor] set];
					ly = y;
					path = [NSBezierPath bezierPath];
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += maxImageHeight;
					path = [NSBezierPath bezierPath];
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += artworkTextPadding;
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
					ly += maxTextHeight;
					[path moveToPoint:NSMakePoint(0, ly)];
					[path lineToPoint:NSMakePoint(p->pageWidth, ly)];
					[path stroke];
				}
				[NSGraphicsContext restoreGraphicsState];
			}
		}
	}
	if (inPage)
		[c endPage];

	[albumItems release];
	[fs release];

	[c end];
	[c release];
	return data;
}
