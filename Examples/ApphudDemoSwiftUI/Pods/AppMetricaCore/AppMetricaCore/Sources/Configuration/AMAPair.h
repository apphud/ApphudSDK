
#import <Foundation/Foundation.h>

@interface AMAPair : NSObject

@property (nonatomic, strong, readonly) NSString *key;
@property (nonatomic, strong, readonly) NSString *value;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithKey:(NSString *)key value:(NSString *)value;

@end
