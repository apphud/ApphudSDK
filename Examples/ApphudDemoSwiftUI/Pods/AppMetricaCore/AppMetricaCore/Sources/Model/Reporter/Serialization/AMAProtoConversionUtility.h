
#import <Foundation/Foundation.h>
#import <AppMetricaProtobuf/AppMetricaProtobuf.h>
#import "AMAOptionalBool.h"
#import "AMAEventSource.h"
#import "EventData.pb-c.h"
#import "AppMetrica.pb-c.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMAProtoConversionUtility : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (BOOL)fillBoolValue:(protobuf_c_boolean *)value withOptionalBool:(AMAOptionalBool)optionalBool;
+ (AMAOptionalBool)optionalBoolForBoolValue:(protobuf_c_boolean)value hasValue:(protobuf_c_boolean)hasValue;
+ (Ama__EventData__EventSource)eventSourceToServerProto:(AMAEventSource)model;
+ (AMAEventSource)eventSourceToModel:(Ama__EventData__EventSource)proto;
+ (Ama__ReportMessage__Session__Event__EventSource)eventSourceToLocalProto:(AMAEventSource)model;

@end

NS_ASSUME_NONNULL_END
