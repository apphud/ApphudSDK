
#import <Foundation/Foundation.h>

@interface AMAErrorCustomData : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, copy, readonly) NSString *className;

- (instancetype)initWithIdentifier:(NSString *)identifier
                           message:(NSString *)message
                         className:(NSString *)className;

@end
