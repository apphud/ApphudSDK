
#import <Foundation/Foundation.h>

@interface AMADispatchStrategiesContainer : NSObject

- (void)addStrategies:(NSArray *)strategies;
- (void)startStrategies:(NSArray *)strategies;
- (void)dispatchMoreIfNeeded;
- (void)dispatchMoreIfNeededForApiKey:(NSString *)apiKey;
- (void)shutdown;
- (void)handleConfigurationUpdate;
- (NSSet *)strategies;

@end
