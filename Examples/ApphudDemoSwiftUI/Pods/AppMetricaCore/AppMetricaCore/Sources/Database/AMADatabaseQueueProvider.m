
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMACore.h"
#import <sqlite3.h>
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import "AMADatabaseQueueProvider.h"

@interface AMADatabaseQueueProvider ()

@property (nonatomic, strong, readonly) NSPointerArray *createdQueues;

@end

@implementation AMADatabaseQueueProvider

@synthesize logsEnabled = _logsEnabled;

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _logsEnabled = NO;
        _createdQueues = [NSPointerArray weakObjectsPointerArray];
    }
    return self;
}

- (NSString *)addNolockFlag:(NSString *)path
{
    return [NSString stringWithFormat:@"file:%@?nolock=1", path];
}

- (AMAFMDatabaseQueue *)inMemoryQueue
{
    return [[AMAFMDatabaseQueue alloc] initWithPath:nil];
}

- (AMAFMDatabaseQueue *)queueForPath:(NSString *)path
{
    [AMAFileUtility createPathIfNeeded:[path stringByDeletingLastPathComponent]];
    AMALogInfo(@"Database path: %@", path);

    [AMAFileUtility removeFileProtectionForPath:path];

    NSString *databaseOpenPath = [AMAPlatformDescription isExtension] ? [self addNolockFlag:path] : path;
    AMAFMDatabaseQueue *dbQueue = [[AMAFMDatabaseQueue alloc] initWithPath:databaseOpenPath
                                                                     flags:(SQLITE_OPEN_READWRITE |
                                                                            SQLITE_OPEN_CREATE |
                                                                            SQLITE_OPEN_FILEPROTECTION_NONE)];
    if ([AMAFileUtility setSkipBackupAttributesOnPath:path] == NO) {
        AMALogWarn(@"Failed to set the skip-backup attribute");
    }

    [dbQueue inDatabase:^(AMAFMDatabase *db) {
        db.logsErrors = self.logsEnabled;
        [db executeUpdate:@"PRAGMA auto_vacuum=FULL"];
    }];

    @synchronized (self) {
        [self.createdQueues addPointer:(__bridge void *)dbQueue];
    }

    return dbQueue;
}

- (BOOL)logsEnabled
{
    @synchronized (self) {
        return _logsEnabled;
    }
}

- (void)setLogsEnabled:(BOOL)logsEnabled
{
    NSArray *queues = nil;
    @synchronized (self) {
        if (_logsEnabled == logsEnabled) {
            return;
        }
        _logsEnabled = logsEnabled;
        [self.createdQueues compact];
        queues = [self.createdQueues allObjects];
    }
    for (AMAFMDatabaseQueue *queue in queues) {
        [queue inDatabase:^(AMAFMDatabase *db) {
            db.logsErrors = logsEnabled;
        }];
    }
}

+ (instancetype)sharedInstance
{
    static AMADatabaseQueueProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMADatabaseQueueProvider alloc] init];
    });
    return instance;
}


@end
