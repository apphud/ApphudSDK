#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAExtrasComposer <NSObject>

- (NSDictionary<NSString *, NSData *> *)compose;

@end

NS_ASSUME_NONNULL_END
