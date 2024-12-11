
#import <Foundation/Foundation.h>

@class AMAReporter;
@class AMAAttributionModelConfiguration;

@interface AMAAttributionController : NSObject

@property (nonatomic, strong, readwrite) AMAAttributionModelConfiguration *config;
@property (nonatomic, strong, readwrite) AMAReporter *mainReporter;

+ (instancetype)sharedInstance;
- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config;

@end
