#import "AMAEventsCountStorageTrimmer.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMAStorageEventsTrimTransaction.h"
#import "AMAMetricaConfiguration.h"
#import "AMAReporterConfiguration.h"
#import "AMADatabaseHelper.h"

@interface AMAEventsCountStorageTrimmer ()

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) AMAStorageEventsTrimTransaction *trimTransaction;

@property (nonatomic, assign) NSUInteger aproximateEventsCount;

@end

@implementation AMAEventsCountStorageTrimmer

- (instancetype)initWithApiKey:(NSString *)apiKey
               trimTransaction:(AMAStorageEventsTrimTransaction *)trimTransaction
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _trimTransaction = trimTransaction;
        _aproximateEventsCount = NSUIntegerMax - 1;
    }
    return self;
}

#pragma mark - Public -

- (void)handleEventAdding
{
    self.aproximateEventsCount++;
}

#pragma mark - AMAStorageTrimming -

- (void)trimDatabase:(id<AMADatabaseProtocol>)database
{
    if (database == nil) {
        return;
    }
    if ([self shouldTrimDatabase:database]) {
        [self.trimTransaction performTransactionInDatabase:database];
    }
}

#pragma mark - Private -

- (BOOL)shouldTrimDatabase:(id<AMADatabaseProtocol>)database
{
    AMAReporterConfiguration *configuration =
        [[AMAMetricaConfiguration sharedInstance] configurationForApiKey:self.apiKey];
    NSUInteger maxEventsCount = configuration.maxReportsInDatabaseCount;
    NSUInteger eventsCount = self.aproximateEventsCount;

    if (eventsCount > maxEventsCount) {
        eventsCount = [self countOfEventsInDatabase:database];
        self.aproximateEventsCount = eventsCount;
    }

    BOOL shouldTrim = eventsCount > maxEventsCount;
    if (shouldTrim) {
        AMALogInfo(@"Database will be trimmed, events count %lu, max allowed %lu",
                           (unsigned long)eventsCount, (unsigned long)maxEventsCount);
    }

    return shouldTrim;
}

- (NSUInteger)countOfEventsInDatabase:(id<AMADatabaseProtocol>)database
{
    NSUInteger __block count = 0;
    [database inDatabase:^(AMAFMDatabase *db) {
        count = [AMADatabaseHelper countWhereField:nil
                                           inArray:nil
                                         tableName:kAMAEventTableName
                                                db:db
                                             error:NULL];
    }];
    return count;
}

@end
