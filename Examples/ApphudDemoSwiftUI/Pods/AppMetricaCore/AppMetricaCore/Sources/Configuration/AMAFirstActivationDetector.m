
#import "AMAFirstActivationDetector.h"
#import "AMAMigrationTo500Utils.h"
#import "AMACore.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMADatabaseFactory.h"

@interface AMAFirstActivationDetector ()

@property (nonatomic, assign, readonly) BOOL isFirstLibraryReporterActivation;
@property (nonatomic, assign, readonly) BOOL isFirstMainReporterActivation;

@end

@implementation AMAFirstActivationDetector

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _isFirstLibraryReporterActivation = [self isReporterUnavailable:kAMAMetricaLibraryApiKey];
        _isFirstMainReporterActivation = [self isReporterUnavailable:kAMAMainReporterDBPath];
    }
    return self;
}

- (BOOL)isReporterUnavailable:(NSString *)path
{
    NSString *libraryReporterMigrationPath = [[AMAMigrationTo500Utils migrationPath] stringByAppendingPathComponent:path];
    NSString *libraryReporterPath = [AMAFileUtility persistentPathForApiKey:path];
    
    NSString *(^dbFilePath)(NSString *) = ^NSString *(NSString *basePath) {
        return [basePath stringByAppendingPathComponent:@"data.sqlite"];
    };
    
    return ![AMAFileUtility fileExistsAtPath:dbFilePath(libraryReporterMigrationPath)] &&
           ![AMAFileUtility fileExistsAtPath:dbFilePath(libraryReporterPath)];
}

@end
