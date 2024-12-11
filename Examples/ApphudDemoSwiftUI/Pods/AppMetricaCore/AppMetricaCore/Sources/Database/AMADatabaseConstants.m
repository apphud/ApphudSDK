
#import "AMADatabaseConstants.h"

NSString *const kAMADatabaseKeySchemaVersion = @"schema.version";
NSString *const kAMADatabaseKeyLibraryVersion = @"library.version";
NSString *const kAMADatabaseKeyInconsistentDatabaseDetectedSchema = @"database.inconsistent.schema";

NSString *const kAMACommonTableFieldOID = @"id";
NSString *const kAMACommonTableFieldType = @"type";
NSString *const kAMACommonTableFieldDataEncryptionType = @"data_encryption_type";
NSString *const kAMACommonTableFieldData = @"data";

NSString *const kAMAEventTableName = @"events";
NSString *const kAMAEventTableFieldSessionOID = @"session_oid";
NSString *const kAMAEventTableFieldCreatedAt = @"created_at";
NSString *const kAMAEventTableFieldSequenceNumber = @"sequence_number";

NSString *const kAMASessionTableName = @"sessions";
NSString *const kAMASessionTableFieldStartTime = @"start_time";
NSString *const kAMASessionTableFieldFinished = @"finished";
NSString *const kAMASessionTableFieldLastEventTime = @"last_event_time";
NSString *const kAMASessionTableFieldPauseTime = @"pause_time";
NSString *const kAMASessionTableFieldEventSeq = @"event_seq";

NSString *const kAMAKeyValueTableName = @"kv";
NSString *const kAMAKeyValueTableFieldKey = @"k";
NSString *const kAMAKeyValueTableFieldValue = @"v";

NSString *const kAMALocationsTableName = @"items";
NSString *const kAMALocationsVisitsTableName = @"visits";
NSString *const kAMALocationsTableFieldTimestamp = @"timestamp";
