#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const QYPTEngineErrorDomain;

typedef NS_ENUM(NSInteger, QYPTEngineErrorCode) {
    QYPTEngineErrorNotFound = 1,
    QYPTEngineErrorBadResponse = 2,
    QYPTEngineErrorCommandFailed = 3,
};

@interface QYPTEngineClient : NSObject

+ (void)runCommand:(NSString *)command
         arguments:(NSArray<NSString *> *)arguments
        completion:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
