
#import <Foundation/Foundation.h>

@interface AMALibrarySymbolsProvider : NSObject

+ (NSArray<Class> *)classes;
+ (NSArray<NSString *> *)dynamicBinaries;

@end
