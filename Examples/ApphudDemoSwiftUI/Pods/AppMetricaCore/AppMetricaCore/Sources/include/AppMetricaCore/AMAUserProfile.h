
#import <Foundation/Foundation.h>

@class AMAUserProfileUpdate;

NS_ASSUME_NONNULL_BEGIN

/** The class to store a user profile.
 User profile is a set of user attributes.
 User profile details are displayed in the AppMetrica User profiles report.

 The UserProfile object should be passed to the AppMetrica server by using the `reportUserProfile`
 method of the `AMAAppMetrica` class.

 AppMetrica has some predefined attributes. You can use them or create own custom attributes. Use the
 `AMAProfileAttribute` interface to create attributes.

 User profiles are stored on the AppMetrica server.
 */
NS_SWIFT_NAME(UserProfile)
@interface AMAUserProfile : NSObject <NSCopying, NSMutableCopying>

/** An array with applied attributes.
 */
@property (nonatomic, copy, readonly) NSArray<AMAUserProfileUpdate *> *updates;

/** Initialize user profile with specified applied attributes.

 @param updates An array with profile updates
 */
- (instancetype)initWithUpdates:(NSArray<AMAUserProfileUpdate *> *)updates;

@end

/** Mutable version of the `AMAUserProfile` class.
 */
NS_SWIFT_NAME(MutableUserProfile)
@interface AMAMutableUserProfile : AMAUserProfile

/** Applies single user profile update.

 @param update The `AMAUserProfileUpdate` object
 */
- (void)apply:(AMAUserProfileUpdate *)update;

/** Applies user profile updates.

 @param updatesArray The array of `AMAUserProfileUpdate` objects
 */
- (void)applyFromArray:(NSArray<AMAUserProfileUpdate *> *)updatesArray;

@end

NS_ASSUME_NONNULL_END
