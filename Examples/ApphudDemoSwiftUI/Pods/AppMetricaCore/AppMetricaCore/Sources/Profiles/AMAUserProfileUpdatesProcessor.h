
#import <Foundation/Foundation.h>

@class AMAUserProfileModelSerializer;
@class AMAUserProfileUpdate;

@interface AMAUserProfileUpdatesProcessor : NSObject

- (instancetype)init;
- (instancetype)initWithSerializer:(AMAUserProfileModelSerializer *)serializer;

- (NSData *)dataWithUpdates:(NSArray<AMAUserProfileUpdate *> *)updates error:(NSError **)error;

@end
