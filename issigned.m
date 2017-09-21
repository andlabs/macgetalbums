// 2 september 2017
#import "macgetalbums.h"

// thanks to https://oleb.net/blog/2012/02/checking-code-signing-and-sandboxing-status-in-code/ for pointing me toward the Code Signing Services

BOOL isSigned = NO;
OSStatus isSignedErr = errSecSuccess;

// returns YES if the check succeeded; NO if it did not
BOOL checkIfSigned(void)
{
	SecCodeRef me;

	isSignedErr = SecCodeCopySelf(kSecCSDefaultFlags, &me);
	if (isSignedErr != errSecSuccess)
		return NO;
	isSignedErr = SecCodeCheckValidity(me, kSecCSDefaultFlags, NULL);
	// this is correct for SecCodeRefs (it bridges to id according to Security/CFCommon.h); thanks Zorg and gwynne in irc.freenode.net/#macdev
	CFRelease(me);
	switch (isSignedErr) {
	case errSecSuccess:
		isSigned = YES;
		// fall through
	case errSecCSUnsigned:
		// this isn't really an error so return no error
		// (and in the case we are signed, this is a no-op)
		isSignedErr = errSecSuccess;
		return YES;
	}
	return NO;
}
