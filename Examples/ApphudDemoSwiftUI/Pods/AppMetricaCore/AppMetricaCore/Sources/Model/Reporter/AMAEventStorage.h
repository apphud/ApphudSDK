
#import <Foundation/Foundation.h>

@protocol AMADatabaseProtocol;
@class AMAEvent;
@class AMASession;
@class AMAEventNumbersFiller;
@class AMAEventSerializer;

NS_ASSUME_NONNULL_BEGIN

@interface AMAEventStorage : NSObject

@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, strong, readonly) AMAEventSerializer *eventSerializer;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                 eventSerializer:(AMAEventSerializer *)eventSerializer;
- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                 eventSerializer:(AMAEventSerializer *)eventSerializer
               eventNumberFiller:(AMAEventNumbersFiller *)eventNumberFiller;

- (BOOL)addEvent:(AMAEvent *)event toSession:(AMASession *)session error:(NSError **)error;

- (NSUInteger)totalCountOfEventsWithTypes:(nullable NSArray *)includedTypes;
- (NSUInteger)totalCountOfEventsWithTypes:(nullable NSArray *)includedTypes
                           excludingTypes:(nullable NSArray *)excludedTypes;
- (NSArray<AMAEvent*> *)allEvents;

@end

NS_ASSUME_NONNULL_END
