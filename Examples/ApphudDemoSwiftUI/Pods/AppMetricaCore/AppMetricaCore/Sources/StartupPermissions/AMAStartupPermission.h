
#import <Foundation/Foundation.h>

@interface AMAStartupPermission : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) BOOL enabled;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name enabled:(BOOL)enabled;

@end

