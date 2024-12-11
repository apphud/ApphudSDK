
#import <Security/Security.h>
#import <Foundation/Foundation.h>

@interface AMASecItemOperationResult : NSObject

@property (nonatomic, assign, readonly) OSStatus status;
@property (nonatomic, copy, readonly) NSDictionary *attributes;

- (instancetype)initWithStatus:(OSStatus)status attributes:(NSDictionary *)attributes;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
