
#import "AMARevenueInfoProcessor.h"
#import "AMARevenueInfoModelValidator.h"
#import "AMARevenueInfoModelSerializer.h"
#import "AMARevenueInfoModelFormatter.h"
#import "AMATruncatedDataProcessingResult.h"
#import "AMARevenueInfoModel.h"

@interface AMARevenueInfoProcessor ()

@property (nonatomic, strong, readonly) AMARevenueInfoModelFormatter *formatter;
@property (nonatomic, strong, readonly) AMARevenueInfoModelValidator *validator;
@property (nonatomic, strong, readonly) AMARevenueInfoModelSerializer *serializer;

@end

@implementation AMARevenueInfoProcessor

- (instancetype)init
{
    AMARevenueInfoModelFormatter *formatter = [[AMARevenueInfoModelFormatter alloc] init];
    AMARevenueInfoModelValidator *validator = [[AMARevenueInfoModelValidator alloc] init];
    AMARevenueInfoModelSerializer *serializer = [[AMARevenueInfoModelSerializer alloc] init];
    return [self initWithFormatter:formatter validator:validator serializer:serializer];
}

- (instancetype)initWithFormatter:(AMARevenueInfoModelFormatter *)formatter
                        validator:(AMARevenueInfoModelValidator *)validator
                       serializer:(AMARevenueInfoModelSerializer *)serializer
{
    self = [super init];
    if (self != nil) {
        _formatter = formatter;
        _validator = validator;
        _serializer = serializer;
    }
    return self;
}

- (AMATruncatedDataProcessingResult *)processRevenueModel:(AMARevenueInfoModel *)revenueModel error:(NSError **)error
{
    AMATruncatedDataProcessingResult *result = nil;
    if (revenueModel != nil) {
        AMARevenueInfoModel *formattedModel = [self.formatter formattedRevenueModel:revenueModel error:error];
        if (formattedModel != nil) {
            BOOL isValid = [self.validator validateRevenueInfoModel:formattedModel error:error];
            if (isValid) {
                NSData *data = [self.serializer dataWithRevenueInfoModel:formattedModel];
                result = [[AMATruncatedDataProcessingResult alloc] initWithData:data
                                                                 bytesTruncated:formattedModel.bytesTruncated];
            }
        }
    }
    return result;
}

@end
