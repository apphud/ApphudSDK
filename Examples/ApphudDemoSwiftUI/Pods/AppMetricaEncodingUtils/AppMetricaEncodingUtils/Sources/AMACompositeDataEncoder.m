
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

typedef NSData *(^AMACompositeDataEncoderProcessor)(id<AMADataEncoding> encoder, NSData *data, NSError **error);

@interface AMACompositeDataEncoder ()

@property (nonatomic, copy, readonly) NSArray<id<AMADataEncoding>> *encoders;

@end

@implementation AMACompositeDataEncoder

- (instancetype)initWithEncoders:(NSArray<id<AMADataEncoding>> *)encoders
{
    self = [super init];
    if (self != nil) {
        _encoders = [encoders copy];
    }
    return self;
}

- (NSData *)encodeData:(NSData *)data error:(NSError **)error
{
    NSError *__block internalError = nil;
    NSData *__block result = data;
    [self.encoders enumerateObjectsUsingBlock:^(id<AMADataEncoding> encoder, NSUInteger idx, BOOL *stop) {
        result = [encoder encodeData:result error:&internalError];
        if (internalError != nil) {
            *stop = YES;
        }
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (NSData *)decodeData:(NSData *)data error:(NSError **)error
{
    NSError *__block internalError = nil;
    NSData *__block result = data;
    [self.encoders enumerateObjectsWithOptions:NSEnumerationReverse
                                    usingBlock:^(id<AMADataEncoding> encoder, NSUInteger idx, BOOL *stop) {
        result = [encoder decodeData:result error:&internalError];
        if (internalError != nil) {
            *stop = YES;
        }
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

@end
