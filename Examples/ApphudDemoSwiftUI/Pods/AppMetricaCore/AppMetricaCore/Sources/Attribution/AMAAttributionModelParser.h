
#import <Foundation/Foundation.h>

@class AMAAttributionModelConfiguration;
@class AMAInternalEventsReporter;

@interface AMAAttributionModelParser : NSObject

- (instancetype)initWithReporter:(AMAInternalEventsReporter *)reporter;
- (AMAAttributionModelConfiguration *)parse:(NSDictionary *)json;

@end
