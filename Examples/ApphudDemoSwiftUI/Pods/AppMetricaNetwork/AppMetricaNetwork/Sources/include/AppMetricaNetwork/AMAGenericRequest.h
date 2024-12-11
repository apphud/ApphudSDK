
#import "AMARequest.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(GenericRequest)
@interface AMAGenericRequest : NSObject<AMARequest>

@property (nonatomic, strong, readonly) NSString *method;
@property (nonatomic, assign, readonly) NSTimeInterval timeout;
@property (nonatomic, assign, readonly) NSURLRequestCachePolicy cachePolicy;

@end

NS_ASSUME_NONNULL_END
