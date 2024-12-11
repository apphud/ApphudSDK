
#import <Foundation/Foundation.h>

@class AMAReporter;

@interface AMAReportersContainer : NSObject

- (AMAReporter *)reporterForApiKey:(NSString *)apiKey;

- (void)setReporter:(AMAReporter *)reporter forApiKey:(NSString *)apiKey;

- (void)restartPrivacyTimer;

@end
