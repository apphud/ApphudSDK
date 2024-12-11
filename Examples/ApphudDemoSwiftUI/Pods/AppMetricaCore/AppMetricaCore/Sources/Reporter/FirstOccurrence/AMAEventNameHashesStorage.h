
#import <Foundation/Foundation.h>

@class AMAEventNameHashesCollection;
@class AMAEventNameHashesSerializer;
@protocol AMAFileStorage;

@interface AMAEventNameHashesStorage : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFileStorage:(id<AMAFileStorage>)fileStorage;
- (instancetype)initWithFileStorage:(id<AMAFileStorage>)fileStorage
                         serializer:(AMAEventNameHashesSerializer *)serializer;

- (BOOL)saveCollection:(AMAEventNameHashesCollection *)collection;
- (AMAEventNameHashesCollection *)loadCollection;

@end
