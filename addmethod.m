// 30 september 2017
#define MAC_OS_X_VERSION_MIN_REQUIRED MAC_OS_X_VERSION_10_0
#define MAC_OS_X_VERSION_MAX_ALLOWED MAC_OS_X_VERSION_10_0
#import <stdlib.h>
#import <string.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import "optpriv.h"

// for more on the version 1 runtime, see http://mirror.informatimago.com/next/developer.apple.com/documentation/Cocoa/Reference/ObjCRuntimeRef/ObjCRuntimeRef.pdf

struct v1Method {
	SEL selector;
	char *typeEncoding;
	IMP imp;
};

struct v1MethodList {
	struct v1MethodList *obsolete;
	int count;
#ifdef __LP64__
	// this part is in Apple's headers, not in the above PDF
	int space;
#endif
	struct v1Method methods[1];
};

static void (*v1_class_addMethods)(Class, struct v1MethodList *) = NULL;

static IMP v1getImplementation(Method m)
{
	return ((struct v1Method *) m)->imp;
}

static const char *v1getTypeEncoding(Method m)
{
	return ((struct v1Method *) m)->typeEncoding;
}

static BOOL v1add(Class class, SEL selector, IMP imp, const char *typeEncoding)
{
	struct v1MethodList *v1list;

	// we must use malloc() because class_addMethods() wants to keep the pointer we pass in
	v1list = (struct v1MethodList *) malloc(sizeof (struct v1MethodList));
	if (v1list == NULL)
		return NO;
	memset(v1list, 0, sizeof (struct v1MethodList));
	v1list->count = 1;
	v1list->methods[0].selector = selector;
	// blame the old declarations for this
	v1list->methods[0].typeEncoding = (char *) (typeEncoding);
	v1list->methods[0].imp = imp;
	(*v1_class_addMethods)(class, v1list);
	return YES;
}

static IMP (*getImplementation)(Method) = NULL;
static const char *(*getTypeEncoding)(Method) = NULL;
static BOOL (*add)(Class, SEL, IMP, const char *) = NULL;

// thanks to gwynne in irc.freenode.net #macdev
// TODO there doesn't seem to be a way to get a mach_header from an address already in memory...
static BOOL tryModule(unsigned long mod)
{
	const struct mach_header *handle;
	NSSymbol a, b, c;

	handle = _dyld_get_image_header(mod);
	if (handle == NULL)
		return NO;

	a = NSLookupSymbolInImage(handle, "_method_getImplementation", NSLOOKUPSYMBOLINIMAGE_OPTION_RETURN_ON_ERROR);
	b = NSLookupSymbolInImage(handle, "_method_getTypeEncoding", NSLOOKUPSYMBOLINIMAGE_OPTION_RETURN_ON_ERROR);
	c = NSLookupSymbolInImage(handle, "_class_addMethod", NSLOOKUPSYMBOLINIMAGE_OPTION_RETURN_ON_ERROR);
	// we must have all three for v2
	if (a != NULL && b != NULL && c != NULL) {
		*((void **) (&getImplementation)) = NSAddressOfSymbol(a);
		*((void **) (&getTypeEncoding)) = NSAddressOfSymbol(b);
		*((void **) (&add)) = NSAddressOfSymbol(c);
		return YES;
	}

	// let's hope we have v1
	a = NSLookupSymbolInImage(handle, "_class_addMethods", NSLOOKUPSYMBOLINIMAGE_OPTION_RETURN_ON_ERROR);
	if (a == NULL)
		return NO;
	*((void **) (&v1_class_addMethods)) = NSAddressOfSymbol(a);
	getImplementation = v1getImplementation;
	getTypeEncoding = v1getTypeEncoding;
	add = v1add;
	return YES;
}

static void getFunctions(void)
{
	unsigned long i, n;

	if (getImplementation != NULL)
		return;
	n = _dyld_image_count();
	for (i = 0; i < n; i++)
		if (tryModule(i))
			return;
	optThrow(@"could not determine which Objective-C runtime functions to use");
}

BOOL addMethod(Class class, SEL new, SEL existing)
{
	Method m;
	IMP imp;
	const char *typeEncoding;

	getFunctions();
	m = class_getInstanceMethod(class, existing);
	imp = (*getImplementation)(m);
	typeEncoding = (*getTypeEncoding)(m);
	return (*add)(class, new, imp, typeEncoding);
}
