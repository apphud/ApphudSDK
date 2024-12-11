
#import "AMAKeychainBridge.h"

@implementation AMAKeychainBridge

- (OSStatus)addEntryWithAttributes:(NSDictionary *)attributes
{
    return SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
}

- (OSStatus)updateEntryWithQuery:(NSDictionary *)query attributesToUpdate:(NSDictionary *)attributes
{
    return SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
}

- (OSStatus)deleteEntryWithQuery:(NSDictionary *)query
{
    return SecItemDelete((__bridge CFDictionaryRef)query);
}

- (OSStatus)copyMatchingEntryWithQuery:(NSDictionary *)query resultData:(NSData **)resultData
{
    CFTypeRef dataRef = NULL;
    OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataRef);
    *resultData = (__bridge_transfer NSData *)dataRef;
    return result;
}

@end
