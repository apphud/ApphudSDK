
#import <Foundation/Foundation.h>

@interface AMACppException : NSObject

@property (nonatomic, copy, readonly) NSString *name;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name;

@end
