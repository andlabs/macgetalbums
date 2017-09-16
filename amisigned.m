// 2 september 2017
#import "macgetalbums.h"

// thanks to https://oleb.net/blog/2012/02/checking-code-signing-and-sandboxing-status-in-code/ for pointing me toward the Code Signing Services

// note: assumes all failures mean unsigned
BOOL amISigned(OSStatus *err)
{
	SecCodeRef me;
	OSStatus xerr;

	if (err == NULL)
		err = &xerr;
	*err = SecCodeCopySelf(kSecCSDefaultFlags, &me);
	if (*err != errSecSuccess)
		return NO;
	*err = SecCodeCheckValidity(me, kSecCSDefaultFlags, NULL);
	// this is correct for SecCodeRefs (it bridges to id according to Security/CFCommon.h); thanks Zorg and gwynne in irc.freenode.net/#macdev
	CFRelease(me);
	switch (*err) {
	case errSecSuccess:
		return YES;
	case errSecCSUnsigned:
		// this isn't really an error so return no error
		*err = errSecSuccess;
		// fall out
	// assume any other error means some failure -> not signed
	}
	return NO;
}
