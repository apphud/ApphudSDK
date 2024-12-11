#import "AMAFilledExtrasComposer.h"
#import "AMAReporterStateStorage.h"
#import "AMAExtrasContainer.h"

@interface AMAFilledExtrasComposer ()
@property (nonatomic, strong) AMAReporterStateStorage *storage;
@end

@implementation AMAFilledExtrasComposer

- (instancetype)initWithStorage:(AMAReporterStateStorage*)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
    }
    return self;
}

- (NSDictionary<NSString *,NSData *> *)compose
{
    return [self.storage.extrasContainer dictionaryExtras];
}

@end
