
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAReportRequestModel.h"
#import "AMAReportEventsBatch.h"

@implementation AMAReportRequestModel

+ (instancetype)reportRequestModelWithApiKey:(NSString *)apiKey
                               attributionID:(NSString *)attributionID
                              appEnvironment:(NSDictionary *)appEnvironment
                                    appState:(AMAApplicationState *)appState
                            inMemoryDatabase:(BOOL)inMemoryDatabase
                               eventsBatches:(NSArray<AMAReportEventsBatch *> *)eventsBatches
{
    return [[AMAReportRequestModel alloc] initWithApiKey:apiKey
                                           attributionID:attributionID
                                          appEnvironment:appEnvironment
                                                appState:appState
                                        inMemoryDatabase:inMemoryDatabase
                                           eventsBatches:eventsBatches];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
                 attributionID:(NSString *)attributionID
                appEnvironment:(NSDictionary *)appEnvironment
                      appState:(AMAApplicationState *)appState
              inMemoryDatabase:(BOOL)inMemoryDatabase
                 eventsBatches:(NSArray<AMAReportEventsBatch *> *)eventsBatches
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _attributionID = [attributionID copy];
        _appEnvironment = [appEnvironment copy];
        _appState = appState;
        _inMemoryDatabase = inMemoryDatabase;
        _eventsBatches = [eventsBatches copy];
    }
    return self;
}

- (instancetype)copyWithEventsBatches:(NSArray<AMAReportEventsBatch *> *)eventsBatches
{
    return [[AMAReportRequestModel alloc] initWithApiKey:self.apiKey
                                           attributionID:self.attributionID
                                          appEnvironment:self.appEnvironment
                                                appState:self.appState
                                        inMemoryDatabase:self.inMemoryDatabase
                                           eventsBatches:eventsBatches];
}

- (instancetype)copyWithAppState:(AMAApplicationState *)appState
{
    return [[AMAReportRequestModel alloc] initWithApiKey:self.apiKey
                                           attributionID:self.attributionID
                                          appEnvironment:self.appEnvironment
                                                appState:appState
                                        inMemoryDatabase:self.inMemoryDatabase
                                           eventsBatches:self.eventsBatches];
}

- (NSArray *)events
{
    NSMutableArray *events = [NSMutableArray array];
    for (AMAReportEventsBatch *batch in self.eventsBatches) {
        if (batch.events != nil) {
            [events addObjectsFromArray:batch.events];
        }
    }
    return [events copy];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    
    if ([object isKindOfClass:AMAReportRequestModel.class] == NO) {
        return NO;
    }
    
    AMAReportRequestModel *other = (AMAReportRequestModel *)object;
    return [self.apiKey isEqualToString:other.apiKey]
        && [self.attributionID isEqualToString:other.attributionID]
        && [self.appEnvironment isEqualToDictionary:other.appEnvironment]
        && [self.appState isEqual:other.appState]
        && self.inMemoryDatabase == other.inMemoryDatabase
        && [self.eventsBatches isEqualToArray:other.eventsBatches];
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;
    
    result = prime * result + self.apiKey.hash;
    result = prime * result + self.attributionID.hash;
    result = prime * result + self.appEnvironment.hash;
    result = prime * result + self.appState.hash;
    result = prime * result + (self.inMemoryDatabase ? 1231 : 1237);
    result = prime * result + self.eventsBatches.hash;
    
    return result;
}

@end
