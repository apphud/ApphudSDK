
#import "AMACore.h"
#import "AMAFramework.h"

@interface AMAFramework ()

@property (nonatomic, strong, readonly) NSBundle *frameworkBundle;
@property (nonatomic, assign, readonly) CFBundleRef frameworkBundleRef;

@end

@implementation AMAFramework

@dynamic name;
@dynamic path;
@dynamic loaded;

- (instancetype)initWithBundleAtPath:(NSString *)path
{
    NSParameterAssert(path);
    if (path == nil) {
        return nil;
    }

    self = [super init];
    if (self != nil) {
        _frameworkBundle = [NSBundle bundleWithPath:path];
        if (_frameworkBundle.bundleURL != nil) {
            _frameworkBundleRef =
                CFBundleCreate(kCFAllocatorDefault, (__bridge CFURLRef)_frameworkBundle.bundleURL);
            BOOL result = [_frameworkBundle load];
            if (result) {
                AMALogInfo(@"Framework bundle loaded: %@", path);
            }
            else {
                AMALogWarn(@"Failed to load framework bundle: %@", path);
            }
        }
        else {
            AMALogWarn(@"Framework bundle not found: %@", path);
        }
    }

    return self;
}

- (BOOL)loaded
{
    return self.frameworkBundle.loaded;
}

- (NSString *)path
{
    return self.frameworkBundle.bundlePath;
}

- (NSString *)name
{
    return [self.frameworkBundle.bundlePath lastPathComponent];
}

- (Class)classFromString:(NSString *)string
{
    if (self.frameworkBundle == NULL || self.loaded == NO || string == nil) {
        return Nil;
    }

    return [self.frameworkBundle classNamed:string];
}

- (void *)functionFromString:(NSString *)string
{
    if (self.frameworkBundleRef == NULL || self.loaded == NO || string == nil) {
        return NULL;
    }

    return CFBundleGetFunctionPointerForName(self.frameworkBundleRef, (__bridge CFStringRef)string);
}

- (id)objectFromString:(NSString *)string
{
    if (self.frameworkBundleRef == NULL || self.loaded == NO || string == nil) {
        return nil;
    }

    void * dataPointer = CFBundleGetDataPointerForName(self.frameworkBundleRef, (__bridge CFStringRef)string);
    id result = nil;
    if (dataPointer != NULL) {
        result = (__bridge id)(*(void **)dataPointer);
    }

    return result;
}

- (void)dealloc
{
    if (_frameworkBundleRef != NULL) {
        AMALogInfo(@"Framework bundle unloaded: %@", _frameworkBundle.bundlePath);
        CFRelease(_frameworkBundleRef);
        _frameworkBundleRef = NULL;
    }
}

@end
