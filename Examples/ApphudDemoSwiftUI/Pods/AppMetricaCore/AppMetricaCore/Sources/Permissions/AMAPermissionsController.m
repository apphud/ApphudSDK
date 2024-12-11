
#import "AMACore.h"
#import "AMAPermissionsController.h"
#import "AMAPermissionsConfiguration.h"
#import "AMAPermissionsSerializer.h"
#import "AMAPermissionsExtractor.h"

@interface AMAPermissionsController ()

@property (nonatomic, strong, readonly) AMAPermissionsConfiguration *configuration;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;
@property (nonatomic, strong, readonly) AMAPermissionsExtractor *extractor;

@end

@implementation AMAPermissionsController

- (instancetype)init
{
    return [self initWithConfiguration:[[AMAPermissionsConfiguration alloc] init]
                             extractor:[[AMAPermissionsExtractor alloc] init]
                          dateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithConfiguration:(AMAPermissionsConfiguration *)configuration
                            extractor:(AMAPermissionsExtractor *)extractor
                         dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
        _extractor = extractor;
        _dateProvider = dateProvider;
    }
    return self;
}

#pragma mark - Public -

- (NSString *)updateIfNeeded
{
    @synchronized(self) {
        if (self.shouldUpdatePermissions) {
            AMALogInfo(@"Updating permissions");
            return [self update];
        }
        return nil;
    }
}

#pragma mark - Private -

- (BOOL)shouldUpdatePermissions
{
    BOOL isAllowed = YES;
    if (self.configuration.collectingEnabled == NO) {
        AMALogInfo(@"Permissions update denied from the configuration");
        isAllowed = NO;
    }
    else if (self.isTimePassed == NO) {
        AMALogInfo(@"Can't update permissions as update interval did not pass");
        isAllowed = NO;
    }
    return isAllowed;
}

- (BOOL)isTimePassed
{
    NSDate *lastUpdate = self.configuration.lastUpdateDate;
    if (lastUpdate != nil) {
        NSTimeInterval timePassed = [self.dateProvider.currentDate timeIntervalSinceDate:lastUpdate];
        return timePassed >= self.configuration.collectingInterval;
    }
    return YES;
}

- (NSString *)update
{
    NSArray *permissions = [self.extractor permissionsForKeys:self.configuration.keys];
    self.configuration.lastUpdateDate = self.dateProvider.currentDate;
    return [AMAPermissionsSerializer JSONStringForPermissions:permissions];
}

@end
