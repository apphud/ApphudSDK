
#import <Foundation/Foundation.h>

@protocol AMANamedMigration <NSObject>

/**
 If KV-storage contains 'true' for this key, migration should not be performed.
 If this key is 'nil' migration will manage execution logic itself.

 @return KV-storage key. @see AMAStorageKeys.h
 */
- (NSString *)migrationKey;

@end
