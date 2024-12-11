#import "AMAExternalAttributionSerializer.h"

#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

#import "ClientExternalAttribution.pb-c.h"

@implementation AMAExternalAttributionSerializer

- (nullable NSData *)serializeExternalAttribution:(NSDictionary *)data
                                           source:(AMAAttributionSource)source
                                            error:(NSError * _Nullable * _Nullable)error
{
    __block NSData *serializedData = nil;
    __block NSError *strongError = nil;
    
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__ClientExternalAttribution message = AMA__CLIENT_EXTERNAL_ATTRIBUTION__INIT;
        
        message.has_attribution_type = TRUE;
        message.attribution_type = [self mapAttributionSourceToProtobufType:source];
        
        NSError *localError = nil;
        NSData *attributionData = [AMAJSONSerialization dataWithJSONObject:data error:&localError];
        
        strongError = localError;
        
        if (attributionData != nil) {
            message.has_value = [AMAProtobufUtilities fillBinaryData:&message.value withData:attributionData tracker:tracker];
            serializedData = [self serializeProtobufMessage:&message];
        }
    }];
    
    if (error != NULL && strongError != nil) {
        [AMAErrorUtilities fillError:error withError:strongError];
    }
    
    return serializedData;
}

- (Ama__ClientExternalAttribution__AttributionType)mapAttributionSourceToProtobufType:(AMAAttributionSource)source
{
    if ([source isEqualToString:kAMAAttributionSourceAppsflyer]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__APPSFLYER;
    } 
    else if ([source isEqualToString:kAMAAttributionSourceAdjust]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__ADJUST;
    } 
    else if ([source isEqualToString:kAMAAttributionSourceKochava]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__KOCHAVA;
    } 
    else if ([source isEqualToString:kAMAAttributionSourceTenjin]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__TENJIN;
    } 
    else if ([source isEqualToString:kAMAAttributionSourceAirbridge]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__AIRBRIDGE;
    }
    else if ([source isEqualToString:kAMAAttributionSourceSingular]) {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__SINGULAR;
    }
    else {
        return AMA__CLIENT_EXTERNAL_ATTRIBUTION__ATTRIBUTION_TYPE__UNKNOWN;
    }
}

- (NSData *)serializeProtobufMessage:(Ama__ClientExternalAttribution *)message
{
    size_t msgLen = ama__client_external_attribution__get_packed_size(message);
    void *buf = malloc(msgLen); // Using malloc instead of tracker to let NSData manage the memory
    size_t packedSize = ama__client_external_attribution__pack(message, buf);
    return [NSData dataWithBytesNoCopy:buf length:packedSize];
}

@end
