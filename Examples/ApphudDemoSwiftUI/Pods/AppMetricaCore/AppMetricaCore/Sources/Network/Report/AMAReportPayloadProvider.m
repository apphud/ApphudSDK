
#import "AMACore.h"
#import "AMAReportPayloadProvider.h"
#import "AMAReportPayloadEncoderFactory.h"
#import "AMAReportSerializer.h"
#import "AMAReportRequestModel.h"
#import "AMAReportEventsBatch.h"
#import "AMAEvent.h"
#import "AMAReportPayload.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import <CoreGraphics/CGBase.h>

NSString *const kAMAReportPayloadProviderErrorDomain = @"io.appmetrica.AMAReportPayloadProvider";

//TODO: Add unit-tests
@interface AMAReportPayloadProvider () <AMAReportSerializerDelegate>

@property (nonatomic, strong, readonly) id<AMADataEncoding> encoder;
@property (nonatomic, strong, readonly) AMAReportSerializer *serializer;

@end

@implementation AMAReportPayloadProvider

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _encoder = [AMAReportPayloadEncoderFactory encoder];
        _serializer = [[AMAReportSerializer alloc] init];
        _serializer.delegate = self;
    }
    return self;
}

#pragma mark - Public -

- (AMAReportPayload *)generatePayloadWithRequestModel:(AMAReportRequestModel *)requestModel error:(NSError **)error
{
    NSUInteger maxProtobufMsgSize = [AMAMetricaConfiguration sharedInstance].inMemory.maxProtobufMsgSize;
    if (maxProtobufMsgSize == 0) {
        [self fillError:error withCode:AMAReportPayloadProviderErrorOther];
        return nil;
    }

    NSError *internalError = nil;
    NSData *reportData = [self.serializer dataForRequestModel:requestModel
                                                    sizeLimit:maxProtobufMsgSize
                                                        error:&internalError];

    if (internalError != nil) {
        switch (internalError.code) {
            case AMAReportSerializerErrorAllocationError:
                [self fillError:error withCode:AMAReportPayloadProviderErrorOther];
                return nil;

            case AMAReportSerializerErrorEmpty:
                [self fillError:error withCode:AMAReportPayloadProviderErrorAllSessionsAreEmpty];
                return nil;
        }
    }

    while (internalError != nil && internalError.code == AMAReportSerializerErrorTooLarge) {
        NSNumber *actualSizeNumber = internalError.userInfo[kAMAReportSerializerErrorKeyActualSize];
        NSParameterAssert(actualSizeNumber);
        CGFloat ratio = (CGFloat)maxProtobufMsgSize / (CGFloat)actualSizeNumber.unsignedIntegerValue;
        NSArray *trimmedEventsBatches = [self trimEventsWithRatio:ratio
                                                           events:requestModel.events
                                                    eventsBatches:requestModel.eventsBatches];
        requestModel = [requestModel copyWithEventsBatches:trimmedEventsBatches];

        internalError = nil;
        reportData = [self.serializer dataForRequestModel:requestModel
                                                sizeLimit:maxProtobufMsgSize
                                                    error:&internalError];
    }

    if (internalError != nil) {
        [self fillError:error withCode:AMAReportPayloadProviderErrorOther];
        return nil;
    }

    NSData *encryptedData = [self.encoder encodeData:reportData error:&internalError];
    if (internalError != nil) {
        AMALogError(@"Failed to encrypt data: %@", internalError);
        [self fillError:error withCode:AMAReportPayloadProviderErrorEncryption];
        return nil;
    }

    return [[AMAReportPayload alloc] initWithReportModel:requestModel data:encryptedData];
}

#pragma mark - Private -

- (NSArray *)trimEventsWithRatio:(CGFloat)ratio events:(NSArray *)events eventsBatches:(NSArray *)eventsBatches
{
    NSArray *orderedEvents = [events sortedArrayUsingComparator:^NSComparisonResult(AMAEvent *lhsEvent, AMAEvent *rhsEvent) {
        return [lhsEvent.oid compare:rhsEvent.oid];
    }];
    NSUInteger eventsCount = [orderedEvents count];
    NSUInteger removeLocation = (NSUInteger)floor(eventsCount * ratio);
    NSUInteger length = eventsCount - removeLocation;
    NSRange removedEventsRange = NSMakeRange(removeLocation, length);
    NSArray *eventsToRemove = [orderedEvents subarrayWithRange:removedEventsRange];
    NSMutableArray *trimmedBatches = [NSMutableArray array];
    for (AMAReportEventsBatch *batch in eventsBatches) {
        NSMutableArray *trimmedEvents = [batch.events mutableCopy];
        [trimmedEvents removeObjectsInArray:eventsToRemove];
        if ([trimmedEvents count] > 0) {
            AMAReportEventsBatch *trimmedBatch = [[AMAReportEventsBatch alloc] initWithSession:batch.session
                                                                                appEnvironment:batch.appEnvironment
                                                                                        events:trimmedEvents];
            if (trimmedBatch != nil) {
                [trimmedBatches addObject:trimmedBatch];
            }
        }
    }
    return trimmedBatches;
}

- (void)fillError:(NSError **)error withCode:(AMAReportPayloadProviderErrorCode)code
{
    [AMAErrorUtilities fillError:error withError:[NSError errorWithDomain:kAMAReportPayloadProviderErrorDomain
                                                                     code:code
                                                                 userInfo:nil]];
}

#pragma mark - AMAReportSerializerDelegate

- (void)reportSerializer:(AMAReportSerializer *)serializer didFailedToReadFileOfEvent:(AMAEvent *)event
{
    [self.delegate reportPayloadProvider:self didFailedToReadFileOfEvent:event];
}

@end
