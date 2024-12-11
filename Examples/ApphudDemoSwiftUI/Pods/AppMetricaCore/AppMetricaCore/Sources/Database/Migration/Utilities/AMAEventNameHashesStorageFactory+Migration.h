
#import "AMAEventNameHashesStorageFactory.h"

@class AMAEventNameHashesStorage;

@interface AMAEventNameHashesStorageFactory (Migration)

+ (AMAEventNameHashesStorage *)migrationStorageForPath:(NSString *)path;

@end
