
#import <Foundation/Foundation.h>
#import "AMADatabaseObjectProviderBlock.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMADatabaseObjectProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMADatabaseObjectProviderBlock)blockForStrings;
+ (AMADatabaseObjectProviderBlock)blockForDataBlobs;

@end

NS_ASSUME_NONNULL_END
