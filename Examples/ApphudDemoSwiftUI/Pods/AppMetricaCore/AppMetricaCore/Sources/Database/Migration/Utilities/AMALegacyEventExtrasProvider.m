
#import "AMALegacyEventExtrasProvider.h"
#import "LegacyEventExtras.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMALegacyEventExtrasProvider

+ (NSData *)legacyExtrasData:(AMAFMDatabase *)db
{
    NSDictionary *legacyExtras = [self getLegacyReporterExtras:db];
    
    return [self packExtras:legacyExtras];
}

+ (NSData *)packExtras:(NSDictionary *)legacyExtras
{
    NSData *__block data = nil;
    
    if (legacyExtras == nil) {
        return NULL;
    }

    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__LegacyEventExtras extras = AMA__LEGACY_EVENT_EXTRAS__INIT;

        NSString *extrasId = legacyExtras[@"user_id"];
        if (extrasId.length > 0) {
            extras.id = [AMAProtobufUtilities addNSString:extrasId toTracker:tracker];
        }
        
        NSString *extrasType = legacyExtras[@"type"];
        if (extrasType.length > 0) {
            extras.type = [AMAProtobufUtilities addNSString:extrasType toTracker:tracker];
        }
        
        NSString *extrasOptions = legacyExtras[@"options"];
        NSString *optionsString = [AMAJSONSerialization stringWithJSONObject:extrasOptions error:nil];
        if (optionsString.length > 0) {
            NSString *truncatedOptions = [[AMATruncatorsFactory extrasMigrationTruncator] truncatedString:optionsString onTruncation:nil];
            extras.options = [AMAProtobufUtilities addNSString:truncatedOptions toTracker:tracker];
        }

        size_t dataSize = ama__legacy_event_extras__get_packed_size(&extras);
        uint8_t *dataBytes = malloc(dataSize);
        ama__legacy_event_extras__pack(&extras, dataBytes);
        data = [NSData dataWithBytesNoCopy:dataBytes length:dataSize];
    }];

    return data;
}

+ (NSDictionary *)getLegacyReporterExtras:(AMAFMDatabase *)db
{
    NSString *query = @"SELECT * FROM kv WHERE k = ?";
    AMAFMResultSet *result = [db executeQuery:query, @"user_info"];
    
    if ([result next]) {
        NSDictionary *resultDictionary = nil;
        id columnValue = [result stringForColumnIndex:1];
        
        if (columnValue != nil && [columnValue isKindOfClass:[NSString class]]) {
            resultDictionary = [AMAJSONSerialization dictionaryWithJSONString:columnValue error:nil];
        }
        
        return [resultDictionary copy];
    }
    
    return nil;
}

@end
