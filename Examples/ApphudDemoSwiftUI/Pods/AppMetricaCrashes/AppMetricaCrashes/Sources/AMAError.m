
#import "AMAError.h"

@interface AMAError ()

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *message;
@property (nonatomic, copy, readwrite) NSDictionary *parameters;
@property (nonatomic, copy, readwrite) NSArray *backtrace;
@property (nonatomic, strong, readwrite) id<AMAErrorRepresentable> underlyingError;

@end

@implementation AMAError

+ (instancetype)errorWithIdentifier:(NSString *)identifier
{
    return [[self class] errorWithIdentifier:identifier
                                     message:nil
                                  parameters:nil
                                   backtrace:nil
                             underlyingError:nil];
}

+ (instancetype)errorWithIdentifier:(NSString *)identifier
                            message:(NSString *)message
                         parameters:(NSDictionary *)parameters
{
    return [[self class] errorWithIdentifier:identifier
                                     message:message
                                  parameters:parameters
                                   backtrace:nil
                             underlyingError:nil];
}

+ (instancetype)errorWithIdentifier:(NSString *)identifier
                            message:(NSString *)message
                         parameters:(NSDictionary *)parameters
                          backtrace:(NSArray *)backtrace
                    underlyingError:(id<AMAErrorRepresentable>)underlyingError
{
    return [[AMAError alloc] initWithIdentifier:identifier
                                        message:message
                                     parameters:parameters
                                      backtrace:backtrace
                                underlyingError:underlyingError];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           message:(NSString *)message
                        parameters:(NSDictionary *)parameters
                         backtrace:(NSArray *)backtrace
                   underlyingError:(id<AMAErrorRepresentable>)underlyingError
{
    self = [super init];
    if (self != nil) {
        _identifier = [identifier copy];
        _message = [message copy];
        _parameters = [parameters copy];
        _backtrace = [backtrace copy];
        _underlyingError = underlyingError;
    }
    return self;
}

@end
