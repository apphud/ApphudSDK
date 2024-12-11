
#import "AMALogOutputFactory.h"
#import "AMALogOutput.h"

@implementation AMALogOutputFactory

- (AMALogOutput *)outputWithChannel:(AMALogChannel)channel
                              level:(AMALogLevel)level
                          formatter:(id<AMALogMessageFormatting>)formatter
                         middleware:(id<AMALogMiddleware>)middleware
{
    return [[AMALogOutput alloc] initWithChannel:channel
                                           level:level
                                       formatter:formatter
                                      middleware:middleware];
}

@end
