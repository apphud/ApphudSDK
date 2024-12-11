
#import <Foundation/Foundation.h>
#import <AppMetricaCore/AppMetricaCore.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppMetricaExtendedReporting)
@protocol AMAAppMetricaExtendedReporting <AMAAppMetricaReporting>

- (void)setSessionExtras:(nullable NSData *)data
                  forKey:(NSString *)key NS_SWIFT_NAME(setSessionExtra(value:for:));

- (void)clearSessionExtras;

/** Reports an event of a specified type to the server. This method is intended for reporting string data.

 @param eventType The type of the event. See AMAEventTypes.h file for reserved event types.
 @param name The name of the event, can be nil.
 @param value The string value of the event, can be nil.
 @param eventEnvironment The event environment data, can be nil.
 @param appEnvironment  The app environment data, can be nil.
 @param extras The additional data for the event, can be nil.
 @param onFailure The block to be called when the operation fails, can be nil.
 */
- (void)reportEventWithType:(NSUInteger)eventType
                       name:(nullable NSString *)name
                      value:(nullable NSString *)value
           eventEnvironment:(nullable NSDictionary *)eventEnvironment
             appEnvironment:(nullable NSDictionary *)appEnvironment
                     extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                  onFailure:(nullable void (^)(NSError *error))onFailure;

/** Reports a binary event of a specified type to the server. This method is intended for reporting binary data.

 @param eventType The type of the event. See AMAEventTypes.h file for reserved event types.
 @param data The data of the event, cannot be nil.
 @param name The name of the event, can be nil.
 @param gZipped The boolean value, determines whether data should be compressed using the gzip compression.
 @param eventEnvironment The event environment data, can be nil.
 @param appEnvironment  The app environment data, can be nil.
 @param extras The additional data for the event, can be nil.
 @param bytesTruncated The number of bytes that have been truncated.
 @param onFailure The block to be called when the operation fails, can be nil.
 */
- (void)reportBinaryEventWithType:(NSUInteger)eventType
                             data:(NSData *)data
                             name:(nullable NSString *)name
                          gZipped:(BOOL)gZipped
                 eventEnvironment:(nullable NSDictionary *)eventEnvironment
                   appEnvironment:(nullable NSDictionary *)appEnvironment
                           extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                   bytesTruncated:(NSUInteger)bytesTruncated
                        onFailure:(nullable void (^)(NSError *error))onFailure;

/** Reports a file event of a specified type to the server. This method is intended for reporting file data.

 @param eventType The type of the event. See AMAEventTypes.h file for reserved event types.
 @param data The data of the event, cannot be nil.
 @param fileName The name of file, cannot be nil.
 @param gZipped The boolean value, determines whether data should be compressed using the gzip compression. If true, encryption is ignored.
 @param encrypted The boolean value, determines whether data should be encrypted.
 @param truncated  The boolean value, determines whether data should be truncated partially or completely.
 @param eventEnvironment The event environment data, can be nil.
 @param appEnvironment  The app environment data, can be nil.
 @param extras The additional data for the event, can be nil.
 @param onFailure The block to be called when the operation fails, can be nil.
 */
- (void)reportFileEventWithType:(NSUInteger)eventType
                           data:(NSData *)data
                       fileName:(NSString *)fileName
                        gZipped:(BOOL)gZipped
                      encrypted:(BOOL)encrypted
                      truncated:(BOOL)truncated
               eventEnvironment:(nullable NSDictionary *)eventEnvironment
                 appEnvironment:(nullable NSDictionary *)appEnvironment
                         extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                      onFailure:(nullable void (^)(NSError *error))onFailure;

@end

NS_ASSUME_NONNULL_END
