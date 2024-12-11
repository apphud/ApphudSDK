
#import <Foundation/Foundation.h>

@class AMAFMResultSet;

typedef id(^AMADatabaseObjectProviderBlock)(AMAFMResultSet *rs, NSUInteger columdIdx);
