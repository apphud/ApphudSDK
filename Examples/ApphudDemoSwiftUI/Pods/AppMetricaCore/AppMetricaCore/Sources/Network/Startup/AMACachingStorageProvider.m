
#import "AMACachingStorageProvider.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseFactory.h"

@interface AMACachingStorageProvider ()

@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;

@end

@implementation AMACachingStorageProvider

- (instancetype)init
{
    return [self initWithDatabase:AMADatabaseFactory.configurationDatabase];
}

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
{
    self = [super init];
    if (self != nil) {
        _database = database;
    }
    return self;
}

- (id<AMAKeyValueStoring>)cachingStorage
{
    return self.database.storageProvider.cachingStorage;
}

@end
