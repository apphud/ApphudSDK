
#import "AMALibrarySymbolsProvider.h"

#if __has_include("AMALibrarySymbols.h")
    #import "AMALibrarySymbols.h"
#else
    #define AMA_LIBRARY_CLASSES
    #define AMA_LIBRARY_DYNAMIC_BINARIES
#endif

@implementation AMALibrarySymbolsProvider

+ (NSArray<Class> *)classes
{
    NSArray *classNames = @[ AMA_LIBRARY_CLASSES ];
    NSMutableArray *classes = [NSMutableArray arrayWithCapacity:classNames.count];
    for (NSString *className in classNames) {
        Class aClass = NSClassFromString(className);
        if (aClass != Nil) {
            [classes addObject:aClass];
        }
    }
    return classes;
}

+ (NSArray<NSString *> *)dynamicBinaries
{
    return @[ AMA_LIBRARY_DYNAMIC_BINARIES ];
}

@end
