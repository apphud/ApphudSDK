
#import "AMAIDFAProvider.h"
#import <AdSupport/AdSupport.h>

@implementation AMAIDFAProvider

- (NSUUID *)advertisingIdentifier
{
    return [[ASIdentifierManager sharedManager] advertisingIdentifier];
}

@end
