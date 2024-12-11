
#import "AMABacktraceSymbolicator.h"
#import "AMABinaryImage.h"
#import "AMABacktrace.h"
#import "AMABacktraceFrame.h"
#import "AMABinaryImageExtractor.h"
#import "AMAKSCrashImports.h"

@interface AMABacktraceSymbolicator ()

@property (nonatomic, assign, readonly) AMADLAddrFunction *dlAddrFunction;
@property (nonatomic, strong, readonly) NSCache<NSNumber *, AMABinaryImage *> *imagesCache;

@end

@implementation AMABacktraceSymbolicator

- (instancetype)init
{
    return [self initWithDLAddrFunction:ksdl_dladdr];
}

- (instancetype)initWithDLAddrFunction:(AMADLAddrFunction *)dlAddrFunction
{
    self = [super init];
    if (self != nil) {
        _dlAddrFunction = dlAddrFunction;
        _imagesCache = [[NSCache alloc] init];
        _imagesCache.countLimit = 100;
    }
    return self;
}

- (AMABacktrace *)backtraceForInstructionAddresses:(NSArray<NSNumber *> *)addresses
                                      binaryImages:(NSSet<AMABinaryImage *> **)binaryImages
{
    if (addresses.count == 0) {
        return nil;
    }

    NSMutableSet *mutableBinaryImages = [NSMutableSet set];
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:addresses.count];
    for (NSNumber *address in addresses) {
        AMABinaryImage *binaryImage = nil;
        AMABacktraceFrame *frame = [self frameForAddress:address binaryImage:&binaryImage];
        if (frame != nil) {
            [frames addObject:frame];
        }
        if (binaryImage != nil) {
            [mutableBinaryImages addObject:binaryImage];
        }
    }
    if (binaryImages != NULL) {
        *binaryImages = [mutableBinaryImages copy];
    }
    return [[AMABacktrace alloc] initWithFrames:[frames copy]];
}

- (AMABacktraceFrame *)frameForAddress:(NSNumber *)address binaryImage:(AMABinaryImage **)binaryImage
{
    if ([address isKindOfClass:[NSNumber class]] == NO) {
        return nil;
    }

    AMABinaryImage *image = nil;
    AMABacktraceFrame *frame = nil;

    Dl_info info = {0};
    uintptr_t instructionAddress = kssymbolicator_callInstructionAddress((uintptr_t)address.unsignedIntegerValue);
    if (self.dlAddrFunction(instructionAddress, &info)) {
        image = [self binaryImageWithHeaderAddress:info.dli_fbase name:info.dli_fname];
        uintptr_t symbolAddress = (uintptr_t)info.dli_saddr;
        BOOL stripped = (info.dli_saddr == info.dli_fbase) || (info.dli_saddr == NULL);
        frame = [[AMABacktraceFrame alloc] initWithLineOfCode:nil
                                           instructionAddress:@(instructionAddress)
                                                symbolAddress:(symbolAddress != 0 ? @(symbolAddress) : nil)
                                                objectAddress:@((uintptr_t)info.dli_fbase)
                                                   symbolName:[self stringForCString:info.dli_sname]
                                                   objectName:[self stringForCString:info.dli_fname].lastPathComponent
                                                     stripped:stripped];
    }
    else {
        image = [self binaryImageWithInstructionAddress:@(instructionAddress)];
        frame = [[AMABacktraceFrame alloc] initWithLineOfCode:nil
                                           instructionAddress:@(instructionAddress)
                                                symbolAddress:nil
                                                objectAddress:@(image.address)
                                                   symbolName:nil
                                                   objectName:image.name.lastPathComponent
                                                     stripped:YES];
    }

    if (binaryImage != NULL) {
        *binaryImage = image;
    }
    return frame;
}

- (AMABinaryImage *)binaryImageWithHeaderAddress:(void *)address name:(const char *)name
{
    AMABinaryImage *image = nil;
    @synchronized (self) {
        NSNumber *key = [NSNumber numberWithUnsignedInteger:(NSUInteger)address];
        image = [self.imagesCache objectForKey:key];
        if (image == nil) {
            image = [AMABinaryImageExtractor imageForImageHeader:address name:name];
            [self.imagesCache setObject:image forKey:key];
        }
    }
    return image;
}

- (AMABinaryImage *)binaryImageWithInstructionAddress:(NSNumber *)address
{
    NSArray *images = [AMABinaryImageExtractor sharedImages];
    NSUInteger instructionAddress = [address unsignedIntegerValue];

    NSUInteger index = [images indexOfObjectPassingTest:^BOOL(AMABinaryImage *obj, NSUInteger idx, BOOL *stop) {
        return obj.address <= instructionAddress && instructionAddress < obj.address + obj.size;
    }];
    if (index == NSNotFound) {
        return nil;
    }
    return images[index];
}

- (NSString *)stringForCString:(const char *)cString
{
    if (cString == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:cString];
}

@end
