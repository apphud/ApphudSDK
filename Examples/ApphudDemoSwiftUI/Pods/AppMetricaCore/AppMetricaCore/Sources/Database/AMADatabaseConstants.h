
#import <Foundation/Foundation.h>

extern NSString *const kAMADatabaseKeySchemaVersion;
extern NSString *const kAMADatabaseKeyLibraryVersion;
extern NSString *const kAMADatabaseKeyInconsistentDatabaseDetectedSchema;

extern NSString *const kAMACommonTableFieldOID;
extern NSString *const kAMACommonTableFieldType;
extern NSString *const kAMACommonTableFieldDataEncryptionType;
extern NSString *const kAMACommonTableFieldData;

extern NSString *const kAMAEventTableName;
extern NSString *const kAMAEventTableFieldSessionOID;
extern NSString *const kAMAEventTableFieldCreatedAt;
extern NSString *const kAMAEventTableFieldSequenceNumber;

extern NSString *const kAMASessionTableName;
extern NSString *const kAMASessionTableFieldStartTime;
extern NSString *const kAMASessionTableFieldFinished;
extern NSString *const kAMASessionTableFieldLastEventTime;
extern NSString *const kAMASessionTableFieldPauseTime;
extern NSString *const kAMASessionTableFieldEventSeq;

extern NSString *const kAMAKeyValueTableName;
extern NSString *const kAMAKeyValueTableFieldKey;
extern NSString *const kAMAKeyValueTableFieldValue;

extern NSString *const kAMALocationsTableName;
extern NSString *const kAMALocationsVisitsTableName;
extern NSString *const kAMALocationsTableFieldTimestamp;
