// 25 september 2017
#import "macgetalbums.h"

#define pageWidth 612
#define pageHeight 792
#define margins 72
#define itemWidth 108
#define padding 18

CFDataRef makePDF(NSSet *albums)
{
	CFMutableDataRef data;
	CGDataConsumerRef consumer;
	CGSize mediaBox;
	CGContextRef c;

	data = CFDataCreateMutable(NULL, 0);
	if (data == NULL) {
		// TODO produce an error
		return NULL;
	}
	consumer = CGDataConsumerCreateWithCFData(data);
	// consumer will retain data according to the Programming Quartz book code samples
	mediaBox = CGSizeMake(pageWidth, pageHeight);
	c = CGPDFContextCreate(consumer, &mediaBox, NULL);
	if (c == NULL) {
		// TODO produce an error
		CGDataConsumerRelease(consumer);
		CFRelease(data);
		return NULL;
	}

	// TODO

	CGPDFContextClose(c);
	CGContextRelease(c);
	CGDataConsumerRelease(consumer);
	return data;
}
