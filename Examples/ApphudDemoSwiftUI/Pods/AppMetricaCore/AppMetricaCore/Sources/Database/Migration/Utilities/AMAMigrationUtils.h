
#import <Foundation/Foundation.h>

@class AMAFMDatabase;
@protocol AMADatabaseProtocol;

@interface AMAMigrationUtils : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (BOOL)addLocationToTable:(NSString *)tableName inDatabase:(AMAFMDatabase *)db;
+ (BOOL)addServerTimeOffsetToSessionsTableInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addErrorEnvironmentToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addAppEnvironmentToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addTruncatedToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addUserInfoInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addLocationEnabledInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addUserProfileIDInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addEncryptionTypeInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addFirstOccurrenceInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addAttributionIDInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addGlobalEventNumberInDatabase:(AMAFMDatabase *)db;
+ (BOOL)addEventNumberOfTypeInDatabase:(AMAFMDatabase *)db;

+ (BOOL)updateColumnTypes:(NSString *)columnTypesDescription ofKeyValueTable:(NSString *)tableName db:(AMAFMDatabase *)db;

+ (void)resetStartupUpdatedAtToDistantPastInDatabase:(id<AMADatabaseProtocol>)database db:(AMAFMDatabase *)db;

@end
