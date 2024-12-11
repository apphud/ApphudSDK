
#import "AMADatabaseObjectProvider.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMADatabaseObjectProvider

+ (AMADatabaseObjectProviderBlock)blockForStrings
{
    return ^(AMAFMResultSet *rs, NSUInteger columnIdx) {
        return [rs stringForColumnIndex:(int)columnIdx];
    };
}

+ (AMADatabaseObjectProviderBlock)blockForDataBlobs
{
    return ^(AMAFMResultSet *rs, NSUInteger columnIdx) {
        return [rs dataForColumnIndex:(int)columnIdx];
    };
}

@end
