
#import <Foundation/Foundation.h>

@interface AMAErrorNSErrorData : NSObject

@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, assign, readonly) NSInteger code;

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code;

@end
