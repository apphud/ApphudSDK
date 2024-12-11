
#import <Foundation/Foundation.h>

@class AMAFMDatabaseQueue;
@class AMADatabaseIntegrityManager;
@class AMADatabaseIntegrityProcessor;

@protocol AMADatabaseIntegrityManagerDelegate <NSObject>

- (id)contextForIntegrityManager:(AMADatabaseIntegrityManager *)manager
            thatWillDropDatabase:(AMAFMDatabaseQueue *)database;

- (void)integrityManager:(AMADatabaseIntegrityManager *)manager
    didCreateNewDatabase:(AMAFMDatabaseQueue *)database
                 context:(id)context;

@end

@interface AMADatabaseIntegrityManager : NSObject

@property (nonatomic, weak) id<AMADatabaseIntegrityManagerDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDatabasePath:(NSString *)databasePath;
- (instancetype)initWithDatabasePath:(NSString *)databasePath
                           processor:(AMADatabaseIntegrityProcessor *)processor;

- (AMAFMDatabaseQueue *)databaseWithEnsuredIntegrityWithIsNew:(BOOL *)isNew;

@end
