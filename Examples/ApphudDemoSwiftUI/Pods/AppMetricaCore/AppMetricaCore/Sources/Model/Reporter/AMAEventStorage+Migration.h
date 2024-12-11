
#import "AMAEventStorage.h"

@class AMAFMDatabase;

@interface AMAEventStorage (Migration)

- (BOOL)addEvent:(AMAEvent *)event db:(AMAFMDatabase *)db error:(NSError **)error;

- (BOOL)addMigratedEvent:(AMAEvent *)event error:(NSError **)error;

@end
