
#import "AMACrashLogging.h"
#import "AMABinaryImageExtractor.h"
#import "AMABinaryImage.h"
#import "AMAKSCrashImports.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <objc/runtime.h>

@implementation AMABinaryImageExtractor

#pragma mark - Binary images extraction

+ (NSArray *)sharedImages
{
    static NSArray *images = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        images = [self images];
    });

    return images;
}

+ (NSArray<AMABinaryImage *> *)userApplicationImages
{
    static NSArray *userApplicationImages = nil;
    static dispatch_once_t userOnceToken;
    dispatch_once(&userOnceToken, ^{
        userApplicationImages = [self filterUserImages:self.sharedImages];
    });
    
    return userApplicationImages;
}

+ (NSArray<AMABinaryImage *> *)filterUserImages:(NSArray<AMABinaryImage *> *)images
{
    NSArray *const kSystemPatterns = @[
        @"^/usr/lib",
        @"^/System/Library",
        @"^/Developer",
        @"Xcode.*/Developer",
    ];
    
    NSArray *regexes = [AMACollectionUtilities mapArray:kSystemPatterns withBlock:^id(id item) {
        return [NSRegularExpression regularExpressionWithPattern:item
                                                         options:NSRegularExpressionAnchorsMatchLines
                                                           error:nil];
    }];
    
    NSMutableArray *result = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(AMABinaryImage *obj, NSUInteger idx, BOOL *stop) {
        if ([self path:obj.name hasAtLeastOneMatch:regexes] == NO) {
            [result addObject:obj];
        }
    }];
    return [result copy];
}

+ (BOOL)path:(NSString *)path hasAtLeastOneMatch:(NSArray<NSRegularExpression *> *)patterns
{
    for (NSRegularExpression *regex in patterns) {
        if ([regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)] != nil) {
            return YES;
        }
    }
    return NO;
}

+ (NSArray *)images
{
    int imageCount = ksdl_imageCount();
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:(NSUInteger)imageCount];
    for (int index = 0; index < imageCount; ++index) {
        AMABinaryImage *image = [self imageForImageIndex:index];
        if (image != nil) {
            [images addObject:image];
        }
    }
    return [images copy];
}

+ (AMABinaryImage *)imageForImageIndex:(int)index
{
    KSBinaryImage ksImage = { 0 };
    if (ksdl_getBinaryImage(index, &ksImage) == false) {
        return nil;
    }
    return [self binaryImageForImage:&ksImage];
}

+ (AMABinaryImage *)imageForImageHeader:(void *)machHeaderPtr name:(const char *)name
{
    KSBinaryImage ksImage = { 0 };
    if (ksdl_getBinaryImageForHeader(machHeaderPtr, name, &ksImage) == false) {
        return nil;
    }
    return [self binaryImageForImage:&ksImage];
}

+ (AMABinaryImage *)binaryImageForImage:(KSBinaryImage *)ksImage
{
    CFUUIDRef uuidRef = CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes *)ksImage->uuid));
    NSString *imageUUID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);

    return [[AMABinaryImage alloc] initWithName:[self stringForCString:ksImage->name]
                                           UUID:imageUUID
                                        address:(NSUInteger)ksImage->address
                                           size:(NSUInteger)ksImage->size
                                      vmAddress:(NSUInteger)ksImage->vmAddress
                                        cpuType:(NSUInteger)ksImage->cpuType
                                     cpuSubtype:(NSUInteger)ksImage->cpuSubType
                                   majorVersion:(int32_t)ksImage->majorVersion
                                   minorVersion:(int32_t)ksImage->minorVersion
                                revisionVersion:(int32_t)ksImage->revisionVersion
                               crashInfoMessage:[self stringForCString:ksImage->crashInfoMessage]
                              crashInfoMessage2:[self stringForCString:ksImage->crashInfoMessage2]];
}

+ (NSString *)stringForCString:(const char *)cString
{
    if (cString == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:cString];
}

@end
