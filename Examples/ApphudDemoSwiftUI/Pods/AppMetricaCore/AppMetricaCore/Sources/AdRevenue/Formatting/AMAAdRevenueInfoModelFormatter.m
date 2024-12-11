
#import "AMACore.h"
#import "AMAAdRevenueInfoModelFormatter.h"
#import "AMAAdRevenueInfoModel.h"
#import "AMAAdRevenueInfoProcessingLogger.h"

static NSUInteger const kAMAStringMaxLength = 100;
static NSUInteger const kAMAPayloadStringLength = 30 * 1024;

@interface AMAAdRevenueInfoModelFormatter ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> stringTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> payloadTruncator;
@property (nonatomic, strong, readonly) AMAAdRevenueInfoProcessingLogger *logger;

@end

@implementation AMAAdRevenueInfoModelFormatter

- (instancetype)init
{
    return [self initWithStringTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:kAMAStringMaxLength]
                        payloadTruncator:[[AMABytesStringTruncator alloc] initWithMaxBytesLength:kAMAPayloadStringLength]
                                  logger:[[AMAAdRevenueInfoProcessingLogger alloc] init]];
}

- (instancetype)initWithStringTruncator:(id<AMAStringTruncating>)stringTruncator
                       payloadTruncator:(id<AMAStringTruncating>)payloadTruncator
                                 logger:(AMAAdRevenueInfoProcessingLogger *)logger
{
    self = [super init];
    if (self != nil) {
        _stringTruncator = stringTruncator;
        _payloadTruncator = payloadTruncator;
        _logger = logger;
    }
    return self;
}


#pragma mark - Public -

- (AMAAdRevenueInfoModel *)formattedAdRevenueModel:(AMAAdRevenueInfoModel *)adRevenueModel
{
    NSUInteger bytesTruncated = 0;
    NSString *truncCurrency = [self truncatedCurrency:adRevenueModel.currency bytesTruncated:&bytesTruncated];
    NSString *truncNetwork = [self truncatedAdNetwork:adRevenueModel.adNetwork bytesTruncated:&bytesTruncated];
    NSString *truncUnitID = [self truncatedAdUnitID:adRevenueModel.adUnitID bytesTruncated:&bytesTruncated];
    NSString *truncUnitName = [self truncatedAdUnitName:adRevenueModel.adUnitName bytesTruncated:&bytesTruncated];
    NSString *truncPlacementID = [self truncatedAdPlacementID:adRevenueModel.adPlacementID bytesTruncated:&bytesTruncated];
    NSString *truncPlacementName = [self truncatedAdPlacementName:adRevenueModel.adPlacementName bytesTruncated:&bytesTruncated];
    NSString *truncPrecision = [self truncatedPrecision:adRevenueModel.precision bytesTruncated:&bytesTruncated];
    NSString *truncPayloadString = [self truncatedPayloadString:adRevenueModel.payloadString bytesTruncated:&bytesTruncated];

    AMAAdRevenueInfoModel *model = [[AMAAdRevenueInfoModel alloc] initWithAmount:adRevenueModel.amount
                                                                        currency:truncCurrency
                                                                          adType:adRevenueModel.adType
                                                                       adNetwork:truncNetwork
                                                                        adUnitID:truncUnitID
                                                                      adUnitName:truncUnitName
                                                                   adPlacementID:truncPlacementID
                                                                 adPlacementName:truncPlacementName
                                                                       precision:truncPrecision
                                                                   payloadString:truncPayloadString
                                                                  bytesTruncated:bytesTruncated];
    return model;
}

#pragma mark - Private -

- (NSString *)truncatedCurrency:(NSString *)currency bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:currency onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"currency" value:currency maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedAdNetwork:(NSString *)adNetwork bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:adNetwork onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"network" value:adNetwork maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedAdUnitID:(NSString *)adUnitID bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:adUnitID onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"unitID" value:adUnitID maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedAdUnitName:(NSString *)adUnitName bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:adUnitName onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"unit name" value:adUnitName maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedAdPlacementName:(NSString *)adPlacementName bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:adPlacementName onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"placement name" value:adPlacementName maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedAdPlacementID:(NSString *)adPlacementID bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:adPlacementID onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"placementID" value:adPlacementID maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedPrecision:(NSString *)precision bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.stringTruncator truncatedString:precision onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"precision" value:precision maxLength:kAMAStringMaxLength];
    }];
}

- (NSString *)truncatedPayloadString:(NSString *)payloadString bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.payloadTruncator truncatedString:payloadString onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfPayloadString:payloadString maxLength:kAMAPayloadStringLength];
    }];
}

@end
