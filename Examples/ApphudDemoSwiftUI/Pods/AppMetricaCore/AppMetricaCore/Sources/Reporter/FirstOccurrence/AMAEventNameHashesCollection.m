
#import "AMAEventNameHashesCollection.h"

@implementation AMAEventNameHashesCollection

- (instancetype)initWithCurrentVersion:(NSString *)currentVersion
         hashesCountFromCurrentVersion:(NSUInteger)hashesCountFromCurrentVersion
              handleNewEventsAsUnknown:(BOOL)handleNewEventsAsUnknown
                       eventNameHashes:(NSMutableSet<NSNumber *> *)eventNameHashes
{
    self = [super init];
    if (self != nil) {
        _currentVersion = [currentVersion copy];
        _hashesCountFromCurrentVersion = hashesCountFromCurrentVersion;
        _handleNewEventsAsUnknown = handleNewEventsAsUnknown;
        _eventNameHashes = eventNameHashes;
    }
    return self;
}

@end
