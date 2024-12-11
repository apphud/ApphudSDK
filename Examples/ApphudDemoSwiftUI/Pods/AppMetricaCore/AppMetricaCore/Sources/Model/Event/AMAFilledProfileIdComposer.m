
#import "AMAFilledProfileIdComposer.h"
#import "AMAReporterStateStorage.h"

@interface AMAFilledProfileIdComposer()

@property (nonatomic, strong, readonly) AMAReporterStateStorage *storage;

@end

@implementation AMAFilledProfileIdComposer

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
    }
    return self;
}

- (NSString *)compose
{
    return self.storage.profileID;
}

@end
