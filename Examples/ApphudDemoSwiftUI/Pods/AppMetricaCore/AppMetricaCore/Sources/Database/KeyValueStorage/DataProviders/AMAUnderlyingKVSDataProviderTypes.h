
#import "AMACore.h"

typedef void(^AMAKVSWithProviderBlock)(id<AMAKeyValueStorageDataProviding> underlyingProvider);
typedef void(^AMAKVSProviderSource)(AMAKVSWithProviderBlock block);
