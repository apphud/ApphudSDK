
#import <Foundation/Foundation.h>

@class AMAFMDatabase;

extern NSString *const kAMAMigrationBundle;

extern NSString *const kAMAMigrationKeychainAccessGroup;
extern NSString *const kAMAMigrationKeychainAppServiceIdentifier;
extern NSString *const kAMAMigrationKeychainVendorServiceIdentifier;

extern NSString *const kAMAMigrationDeviceIDStorageKey;
extern NSString *const kAMAMigrationDeviceIDHashStorageKey;

@interface AMAMigrationTo500Utils : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSString *)migrationPath;

+ (void)migrateTable:(NSString *)tableName
         tableScheme:(NSArray *)tableScheme
            sourceDB:(AMAFMDatabase *)sourceDB
       destinationDB:(AMAFMDatabase *)destinationDB;

+ (void)migrateReporterEvents:(AMAFMDatabase *)sourceDB
                destinationDB:(AMAFMDatabase *)destinationDB
                       apiKey:(NSString *)apiKey;

+ (void)migrateReporterEventHashes:(NSString *)migrationPath
                            apiKey:(NSString *)apiKey;

+ (void)migrateDeviceIDFromDB:(AMAFMDatabase *)db;
+ (void)migrateUUID;

+ (void)migrateCrashReportsIfNeeded;

@end
