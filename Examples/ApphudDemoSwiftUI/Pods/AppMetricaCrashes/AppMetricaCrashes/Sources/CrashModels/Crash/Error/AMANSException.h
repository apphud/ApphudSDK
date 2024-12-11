
#import <Foundation/Foundation.h>

@interface AMANSException : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *userInfo;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name userInfo:(NSString *)userInfo;

@end
