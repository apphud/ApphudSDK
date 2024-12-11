
#import <Foundation/Foundation.h>

@interface AMABacktraceFrame : NSObject

@property (nonatomic, strong, readonly) NSNumber *lineOfCode;
@property (nonatomic, strong, readonly) NSNumber *columnOfCode;
@property (nonatomic, strong, readonly) NSNumber *instructionAddress;
@property (nonatomic, strong, readonly) NSNumber *symbolAddress;
@property (nonatomic, strong, readonly) NSNumber *objectAddress;

@property (nonatomic, copy, readonly) NSString *symbolName;
@property (nonatomic, copy, readonly) NSString *objectName;
@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, copy, readonly) NSString *methodName;
@property (nonatomic, copy, readonly) NSString *sourceFileName;

@property (nonatomic, assign, readonly) BOOL stripped;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithLineOfCode:(NSNumber *)lineOfCode
                instructionAddress:(NSNumber *)instructionAddress
                     symbolAddress:(NSNumber *)symbolAddress
                     objectAddress:(NSNumber *)objectAddress
                        symbolName:(NSString *)symbolName
                        objectName:(NSString *)objectName
                          stripped:(BOOL)stripped;

- (instancetype)initWithClassName:(NSString *)className
                       methodName:(NSString *)methodName
                       lineOfCode:(NSNumber *)lineOfCode
                     columnOfcode:(NSNumber *)columnOfCode
                   sourceFileName:(NSString *)sourceFileName;

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
                    sourceFileName:(NSString *)sourceFileName NS_DESIGNATED_INITIALIZER;

- (instancetype)backtraceFrameByReplacingSymbolName:(NSString *)symbolName
                                      symbolAddress:(NSNumber *)symbolAddress;

@end
