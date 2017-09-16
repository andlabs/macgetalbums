// 2 september 2017
#import "macgetalbums.h"

// thanks to https://oleb.net/blog/2012/02/checking-code-signing-and-sandboxing-status-in-code/ for pointing me toward the Code Signing Services

// TODO rename to isSigned and isSignedErr?
BOOL amISigned = NO;
OSStatus amISignedErr = errSecSuccess;

// returns YES if the check succeeded; NO if it did not
BOOL checkIfSigned(void)
{
	SecCodeRef me;

	amISignedErr = SecCodeCopySelf(kSecCSDefaultFlags, &me);
	if (amISignedErr != errSecSuccess)
		return NO;
	amISignedErr = SecCodeCheckValidity(me, kSecCSDefaultFlags, NULL);
	// this is correct for SecCodeRefs (it bridges to id according to Security/CFCommon.h); thanks Zorg and gwynne in irc.freenode.net/#macdev
	CFRelease(me);
	switch (amISignedErr) {
	case errSecSuccess:
		amISigned = YES;
		// fall through
	case errSecCSUnsigned:
		// this isn't really an error so return no error
		// (and in the case we are signed, this is a no-op)
		amISignedErr = errSecSuccess;
		return YES;
	}
	return NO;
}
