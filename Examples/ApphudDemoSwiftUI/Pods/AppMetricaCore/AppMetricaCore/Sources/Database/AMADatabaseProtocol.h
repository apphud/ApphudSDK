
#import <Foundation/Foundation.h>
#import "AMADatabaseKeyValueStorageProviding.h"

@class AMAFMDatabase;
@class AMARollbackHolder;

typedef NS_ENUM(NSInteger, AMADatabaseType) {
    AMADatabaseTypeUnknown,
    AMADatabaseTypePersistent,
    AMADatabaseTypeInMemory,
};

@protocol AMADatabaseProtocol <NSObject>

@property (nonatomic, assign, readonly) AMADatabaseType databaseType;
@property (nonatomic, copy, readonly) NSString *databasePath;
@property (nonatomic, strong, readonly) id<AMADatabaseKeyValueStorageProviding> storageProvider;

- (void)inDatabase:(void (^)(AMAFMDatabase *db))block;
- (void)inTransaction:(void (^)(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder))block;

- (void)ensureMigrated;
- (void)migrateToMainApiKey:(NSString *)apiKey;
- (NSString *)detectedInconsistencyDescription;
- (void)resetDetectedInconsistencyDescription;

- (void)executeWhenOpen:(dispatch_block_t)block;

@end
