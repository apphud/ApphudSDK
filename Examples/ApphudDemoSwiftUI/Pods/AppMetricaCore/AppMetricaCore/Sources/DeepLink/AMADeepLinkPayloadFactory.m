
#import "AMACore.h"
#import "AMADeepLinkPayloadFactory.h"
#import "AMAErrorsFactory.h"

@implementation AMADeepLinkPayloadFactory

+ (NSDictionary *)deepLinkPayloadForURL:(NSURL *)URL
                                 ofType:(NSString *)type
                                 isAuto:(BOOL)isAuto
                                  error:(NSError **)error
{
    NSString *URLString = URL.absoluteString;
    if (URLString.length == 0 && type.length != 0) {
        [AMAErrorUtilities fillError:error
                          withError:[AMAErrorsFactory emptyDeepLinkUrlOfTypeError:type]];
        return nil;
    }
    else if (URLString.length != 0 && type.length == 0) {
        [AMAErrorUtilities fillError:error
                          withError:[AMAErrorsFactory deepLinkUrlOfUnknownTypeError:URLString]];
        return nil;
    }
    else if (URLString.length == 0 && type.length == 0) {
        [AMAErrorUtilities fillError:error
                          withError:[AMAErrorsFactory emptyDeepLinkUrlOfUnknownTypeError]];
        return nil;
    }
    
    return @{ @"link" : URLString, @"type" : type, @"auto" : @(isAuto) };
}

@end
