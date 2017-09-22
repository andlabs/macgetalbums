// 2 september 2017
#import "macgetalbums.h"

// thanks to https://oleb.net/blog/2012/02/checking-code-signing-and-sandboxing-status-in-code/ for pointing me toward the Code Signing Services

// returns:
// - YES, nil if the check succeeded and we are signed
// - NO, nil if the check succeeded and we are not signed
// - NO, non-nil if the check did not succeed; you must release the error when finished with it
BOOL checkIfSigned(NSError **err)
{
	SecCodeRef me;
	OSStatus errcode;
	CFErrorRef cferr = NULL;

	errcode = SecCodeCopySelf(kSecCSDefaultFlags, &me);
	if (errcode != errSecSuccess) {
		NSDictionary *userInfo;
		CFStringRef errdesc = NULL;

		// we're building our own error object here, and it seems NSError doesn't "know" NSOSStatusErrorDomain enough to provide strings automatically (though it might not do that at all anyway...), so we have to provide NSLocalizedDescriptionKey ourselves
		userInfo = nil;
		errdesc = SecCopyErrorMessageString(errcode, NULL);
		if (errdesc != NULL) {
			userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:(NSString *) errdesc, NSLocalizedDescriptionKey, nil];
			CFRelease(errdesc);
		}
		// there isn't an explicit error domain for Code Signing errors, but SecCodeCheckValidityWithErrors() returns errors with this domain, and there doesn't seem to be any chance of conflicting values (thanks to kaytwo, milky, and mikeash in irc.freenode.net/#macdev)
		*err = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain
			code:((NSInteger) errcode)
			userInfo:userInfo];
		if (userInfo != nil)
			[userInfo release];
		return NO;
	}
	errcode = SecCodeCheckValidityWithErrors(me, kSecCSDefaultFlags, NULL, &cferr);
	// this is correct for SecCodeRefs (it bridges to id according to Security/CFCommon.h); thanks Zorg and gwynne in irc.freenode.net/#macdev
	CFRelease(me);
	switch (errcode) {
	case errSecSuccess:
		*err = nil;
		return YES;
	case errSecCSUnsigned:
		// this isn't really an error so return no error (and the documentation says cferr will not be NULL, so)
		CFRelease(cferr);
		*err = nil;
		return NO;
	}
	// documentation says this won't be nil in this case
	*err = (NSError *) cferr;
	return NO;
}
