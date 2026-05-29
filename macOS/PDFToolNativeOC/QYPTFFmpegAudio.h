#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QYPTFFmpegAudio : NSObject

+ (BOOL)isAvailable;
+ (nullable NSString *)availabilityHint;

+ (void)probeDurationForFile:(NSString *)inputPath
                  completion:(void (^)(NSTimeInterval duration, NSError * _Nullable error))completion;

+ (void)extractAudioFromVideo:(NSString *)videoPath
                   outputPath:(NSString *)outputPath
                       format:(NSString *)format
                   completion:(void (^)(NSString * _Nullable outputPath, NSError * _Nullable error))completion;

+ (void)trimAudioAtPath:(NSString *)inputPath
             outputPath:(NSString *)outputPath
                  start:(NSString *)startTime
                    end:(NSString *)endTime
             completion:(void (^)(NSString * _Nullable outputPath, NSError * _Nullable error))completion;

+ (void)exportAudioAtPath:(NSString *)inputPath
               outputPath:(NSString *)outputPath
                   format:(NSString *)format
               completion:(void (^)(NSString * _Nullable outputPath, NSError * _Nullable error))completion;

+ (NSString *)formatTime:(NSTimeInterval)seconds;

@end

NS_ASSUME_NONNULL_END
