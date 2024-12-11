
#import <Foundation/Foundation.h>

@class AMAAttributeKey;
@class AMAAttributeValue;

@interface AMAUserProfileModel : NSObject

@property (nonatomic, assign) NSUInteger customAttributeKeysCount;
@property (nonatomic, strong) NSMutableDictionary<AMAAttributeKey *, AMAAttributeValue *> *attributes;

@end
