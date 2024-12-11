
#import "AMAProfileAttribute.h"

@class AMAAttributeUpdate;
@protocol AMAAttributeUpdateValidating;

@interface AMAUserProfileUpdate ()

@property (nonatomic, strong, readonly) AMAAttributeUpdate *attributeUpdate;
@property (nonatomic, copy, readonly) NSArray<id<AMAAttributeUpdateValidating>> *validators;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithAttributeUpdate:(AMAAttributeUpdate *)attributeUpdate
                             validators:(NSArray<id<AMAAttributeUpdateValidating>> *)validators;

@end
