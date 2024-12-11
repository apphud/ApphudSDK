
#import <Foundation/Foundation.h>
#import "AMAAttributeType.h"

@interface AMAAttributeKey : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) AMAAttributeType type;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name type:(AMAAttributeType)type;

@end
