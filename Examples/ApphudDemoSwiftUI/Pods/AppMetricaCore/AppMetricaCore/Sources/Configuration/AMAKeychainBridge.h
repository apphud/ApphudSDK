
#import <Foundation/Foundation.h>

@interface AMAKeychainBridge : NSObject

- (OSStatus)addEntryWithAttributes:(NSDictionary *)attributes;
- (OSStatus)updateEntryWithQuery:(NSDictionary *)query attributesToUpdate:(NSDictionary *)attributes;
- (OSStatus)deleteEntryWithQuery:(NSDictionary *)query;
- (OSStatus)copyMatchingEntryWithQuery:(NSDictionary *)query resultData:(NSData **)resultData;

@end
