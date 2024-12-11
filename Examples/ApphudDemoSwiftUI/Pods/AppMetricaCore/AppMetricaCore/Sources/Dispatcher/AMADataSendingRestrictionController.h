
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMADataSendingRestriction) {
    AMADataSendingRestrictionNotActivated = 0,
    AMADataSendingRestrictionUndefined,
    AMADataSendingRestrictionAllowed,
    AMADataSendingRestrictionForbidden,
};

@interface AMADataSendingRestrictionController : NSObject

- (void)setMainApiKey:(NSString *)mainApiKey;
- (void)setMainApiKeyRestriction:(AMADataSendingRestriction)restriction;
- (void)setReporterRestriction:(AMADataSendingRestriction)restriction forApiKey:(NSString *)apiKey;

- (AMADataSendingRestriction)restrictionForApiKey:(NSString *)apiKey;

- (BOOL)shouldEnableLocationSending;
- (BOOL)shouldReportToApiKey:(NSString *)apiKey;

+ (instancetype)sharedInstance;

@end
