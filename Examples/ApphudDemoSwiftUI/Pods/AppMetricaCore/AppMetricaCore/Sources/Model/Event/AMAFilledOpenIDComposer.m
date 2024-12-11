
#import "AMAFilledOpenIDComposer.h"
#import "AMAReporterStateStorage.h"

@interface AMAFilledOpenIDComposer()

@property (nonatomic, strong, readonly) AMAReporterStateStorage *storage;

@end

@implementation AMAFilledOpenIDComposer

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
    }
    return self;
}

- (NSUInteger)compose
{
    return self.storage.openID;
}


@end
