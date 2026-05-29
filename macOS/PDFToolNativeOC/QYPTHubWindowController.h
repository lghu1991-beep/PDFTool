#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QYPTHubWindowController : NSWindowController

- (instancetype)init;
- (void)setOpenPDFHandler:(void (^)(void))handler;
- (void)setOpenAudioHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
