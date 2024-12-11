
#import <Foundation/Foundation.h>
#import "AMACore.h"

@protocol AMADataEncoding;

@interface AMAEncryptedFileStorage : NSObject <AMAFileStorage>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithUnderlyingStorage:(id<AMAFileStorage>)underlyingStorage
                                  encoder:(id<AMADataEncoding>)encoder;

@end
