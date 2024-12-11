
#import <Foundation/Foundation.h>

@class AMAEventNameHashesCollection;

@interface AMAEventNameHashesSerializer : NSObject

- (NSData *)dataForCollection:(AMAEventNameHashesCollection *)collection;
- (AMAEventNameHashesCollection *)collectionForData:(NSData *)data;

@end
