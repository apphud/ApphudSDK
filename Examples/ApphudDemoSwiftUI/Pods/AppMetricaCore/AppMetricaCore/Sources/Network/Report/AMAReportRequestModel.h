
#import <Foundation/Foundation.h>

@class AMAApplicationState;
@class AMAReportEventsBatch;

@interface AMAReportRequestModel : NSObject

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, copy, readonly) NSString *attributionID;
@property (nonatomic, copy, readonly) NSDictionary *appEnvironment;
@property (nonatomic, strong, readonly) AMAApplicationState *appState;
@property (nonatomic, assign, readonly) BOOL inMemoryDatabase;
@property (nonatomic, copy, readonly) NSArray<AMAReportEventsBatch *> *eventsBatches;

+ (instancetype)reportRequestModelWithApiKey:(NSString *)apiKey
                               attributionID:(NSString *)attributionID
                              appEnvironment:(NSDictionary *)appEnvironment
                                    appState:(AMAApplicationState *)appState
                            inMemoryDatabase:(BOOL)inMemoryDatabase
                               eventsBatches:(NSArray<AMAReportEventsBatch *> *)eventsBatches;

- (instancetype)copyWithEventsBatches:(NSArray<AMAReportEventsBatch *> *)eventsBatches;
- (instancetype)copyWithAppState:(AMAApplicationState *)appState;

- (NSArray *)events;

@end
