
#import <Foundation/Foundation.h>

@class AMABinaryImage;

@interface AMABinaryImageExtractor : NSObject

+ (NSArray<AMABinaryImage *> *)sharedImages;
+ (NSArray<AMABinaryImage *> *)userApplicationImages;

+ (AMABinaryImage *)imageForImageHeader:(void *)machHeaderPtr name:(const char *)name;

@end
