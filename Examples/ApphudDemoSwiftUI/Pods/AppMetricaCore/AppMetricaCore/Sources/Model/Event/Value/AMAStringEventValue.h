
#import <Foundation/Foundation.h>
#import "AMAEventValueProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMAStringEventValue : NSObject <AMAEventValueProtocol>

@property (nonatomic, copy, readonly) NSString *value;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
