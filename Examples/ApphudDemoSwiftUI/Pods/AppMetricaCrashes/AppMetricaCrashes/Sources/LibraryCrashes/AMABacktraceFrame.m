
#import "AMABacktraceFrame.h"

@implementation AMABacktraceFrame

- (instancetype)initWithLineOfCode:(NSNumber *)lineOfCode
                instructionAddress:(NSNumber *)instructionAddress
                     symbolAddress:(NSNumber *)symbolAddress
                     objectAddress:(NSNumber *)objectAddress
                        symbolName:(NSString *)symbolName
                        objectName:(NSString *)objectName
                          stripped:(BOOL)stripped
{
    return [self initWithLineOfCode:lineOfCode
                 instructionAddress:instructionAddress
                      symbolAddress:symbolAddress
                      objectAddress:objectAddress
                         symbolName:symbolName
                         objectName:objectName
                           stripped:stripped
                       columnOfCode:nil
                          className:nil
                         methodName:nil
                     sourceFileName:nil];
}

- (instancetype)initWithClassName:(NSString *)className
                       methodName:(NSString *)methodName
                       lineOfCode:(NSNumber *)lineOfCode
                     columnOfcode:(NSNumber *)columnOfCode
                   sourceFileName:(NSString *)sourceFileName
{
    return [self initWithLineOfCode:lineOfCode
                 instructionAddress:nil
                      symbolAddress:nil
                      objectAddress:nil
                         symbolName:nil
                         objectName:nil
                           stripped:NO
                       columnOfCode:columnOfCode
                          className:className
                         methodName:methodName
                     sourceFileName:sourceFileName];
}

- (instancetype)initWithLineOfCode:(NSNumber *)lineOfCode
                instructionAddress:(NSNumber *)instructionAddress
                     symbolAddress:(NSNumber *)symbolAddress
                     objectAddress:(NSNumber *)objectAddress
                        symbolName:(NSString *)symbolName
                        objectName:(NSString *)objectName
                          stripped:(BOOL)stripped
                      columnOfCode:(NSNumber *)columnOfCode
                         className:(NSString *)className
                        methodName:(NSString *)methodName
                    sourceFileName:(NSString *)sourceFileName
{
    self = [super init];
    if (self != nil) {
        _lineOfCode = lineOfCode;
        _instructionAddress = instructionAddress;
        _symbolAddress = symbolAddress;
        _objectAddress = objectAddress;
        _symbolName = [symbolName copy];
        _objectName = [objectName copy];
        _stripped = stripped;
        _columnOfCode = columnOfCode;
        _className = [className copy];
        _methodName = [methodName copy];
        _sourceFileName = [sourceFileName copy];
    }

    return self;
}


- (instancetype)backtraceFrameByReplacingSymbolName:(NSString *)symbolName
                                      symbolAddress:(NSNumber *)symbolAddress
{
    return [[[self class] alloc] initWithLineOfCode:self.lineOfCode
                                 instructionAddress:self.instructionAddress
                                      symbolAddress:symbolAddress
                                      objectAddress:self.objectAddress
                                         symbolName:symbolName
                                         objectName:self.objectName
                                           stripped:NO
                                       columnOfCode:self.columnOfCode
                                          className:self.className
                                         methodName:self.methodName
                                     sourceFileName:self.sourceFileName];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ %@ (%@ + %lu) %@ (+ %lu)", [super description],
                                      self.symbolName,
                                      self.instructionAddress,
                                      self.objectAddress,
                                      self.instructionAddress.unsignedLongValue - self.objectAddress.unsignedLongValue,
                                      self.symbolName,
                                      self.instructionAddress.unsignedLongValue - self.symbolAddress.unsignedLongValue];
}
#endif

@end
