
#import "AMASessionStorage.h"

@interface AMASessionStorage (Migration)

- (BOOL)addMigratedSession:(AMASession *)session error:(NSError **)error;

@end
