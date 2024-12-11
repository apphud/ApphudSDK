
#import "AMACore.h"
#import "AMAAdRevenueInfoProcessor.h"
#import "AMAAdRevenueInfoModelValidator.h"
#import "AMAAdRevenueInfoModelSerializer.h"
#import "AMAAdRevenueInfoModelFormatter.h"
#import "AMATruncatedDataProcessingResult.h"
#import "AMAAdRevenueInfoModel.h"

@interface AMAAdRevenueInfoProcessor ()

@property (nonatomic, strong, readonly) AMAAdRevenueInfoModelFormatter *formatter;
@property (nonatomic, strong, readonly) AMAAdRevenueInfoModelValidator *validator;
@property (nonatomic, strong, readonly) AMAAdRevenueInfoModelSerializer *serializer;

@end

@implementation AMAAdRevenueInfoProcessor

- (instancetype)init
{
    AMAAdRevenueInfoModelFormatter *formatter = [[AMAAdRevenueInfoModelFormatter alloc] init];
    AMAAdRevenueInfoModelValidator *validator = [[AMAAdRevenueInfoModelValidator alloc] init];
    AMAAdRevenueInfoModelSerializer *serializer = [[AMAAdRevenueInfoModelSerializer alloc] init];
    return [self initWithFormatter:formatter validator:validator serializer:serializer];
}

- (instancetype)initWithFormatter:(AMAAdRevenueInfoModelFormatter *)formatter
                        validator:(AMAAdRevenueInfoModelValidator *)validator
                       serializer:(AMAAdRevenueInfoModelSerializer *)serializer
{
    self = [super init];
    if (self != nil) {
        _formatter = formatter;
        _validator = validator;
        _serializer = serializer;
    }
    return self;
}

- (AMATruncatedDataProcessingResult *)processAdRevenueModel:(AMAAdRevenueInfoModel *)adRevenueModel
                                                      error:(NSError **)error
{
    AMATruncatedDataProcessingResult *result = nil;
    if (adRevenueModel != nil) {
        AMAAdRevenueInfoModel *formattedModel = [self.formatter formattedAdRevenueModel:adRevenueModel];
        if (formattedModel != nil) {
            BOOL isValid = [self.validator validateAdRevenueInfoModel:formattedModel error:error];
            if (isValid) {
                NSData *data = [self.serializer dataWithAdRevenueInfoModel:formattedModel];
                result = [[AMATruncatedDataProcessingResult alloc] initWithData:data
                                                                 bytesTruncated:formattedModel.bytesTruncated];
            }
            else {
                NSMutableString *validationError = [NSMutableString stringWithString:@"Failed to validate adRevenue "];
                if (error != NULL && *error != nil) {
                    [validationError appendString:[*error localizedDescription] ?: @""];
                }
                AMALogWarn(@"%@", validationError);
            }
        }
    }
    return result;
}

@end
