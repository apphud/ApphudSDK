
#import <Foundation/Foundation.h>

@class AMAFMDatabase;

@interface AMALegacyEventExtrasProvider : NSObject

+ (NSData *)legacyExtrasData:(AMAFMDatabase *)db;
+ (NSData *)packExtras:(NSDictionary *)legacyExtras;

@end
