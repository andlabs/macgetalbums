// 2 september 2017
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#import <stdio.h>
#import <stdlib.h>

void die(const char *msg, OSStatus err)
{
	CFStringRef str;
	Boolean canString;

	canString = false;
	str = SecCopyErrorMessageString(err, NULL);
	if (str != NULL) {
		const char *p;

		p = CFStringGetCStringPtr(str, kCFStringEncodingUTF8);
		if (p != NULL) {
			fprintf(stderr, "%s: %s (%d)\n", msg, p, err);
			canString = true;
		}
		CFRelease(str);
	}
	if (!canString)
		fprintf(stderr, "%s: %d\n", msg, err);
	exit(1);
}

int main(void)
{
	SecCodeRef me;
	OSStatus err;

	err = SecCodeCopySelf(kSecCSDefaultFlags, &me);
	if (err != errSecSuccess)
		die("error getting signing data for self", err);
	err = SecCodeCheckValidity(me, kSecCSDefaultFlags, NULL);
	switch (err) {
	case errSecSuccess:
		printf("yes we are signed\n");
		return 0;
	case errSecCSUnsigned:
		printf("no we are not signed\n");
		return 0;
	}
	die("error determining whether we are signed", err);
	return 1;		// to appease compiler
}
