
#import <Foundation/Foundation.h>

@class AMARegister;

@interface AMARegistersContainer : NSObject

@property (nonatomic, copy, readonly) NSArray<AMARegister *> *basic;
@property (nonatomic, copy, readonly) NSArray<AMARegister *> *exception;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithBasic:(NSArray<AMARegister *> *)basic exception:(NSArray<AMARegister *> *)exception;

@end
