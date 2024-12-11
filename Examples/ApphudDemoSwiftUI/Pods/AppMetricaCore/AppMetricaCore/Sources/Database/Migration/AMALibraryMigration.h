
#import <Foundation/Foundation.h>

@class AMAFMDatabase;
@protocol AMADatabaseProtocol;

@protocol AMALibraryMigration <NSObject>

@property (nonatomic, copy, readonly) NSString *version;

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database db:(AMAFMDatabase *)db;

@end
