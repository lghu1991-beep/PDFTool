#import "QYPTFFmpegAudio.h"

@implementation QYPTFFmpegAudio

+ (NSArray<NSString *> *)ffmpegCandidates {
    return @[
        @"/opt/homebrew/bin/ffmpeg",
        @"/usr/local/bin/ffmpeg",
        @"/usr/bin/ffmpeg",
    ];
}

+ (NSArray<NSString *> *)ffprobeCandidates {
    return @[
        @"/opt/homebrew/bin/ffprobe",
        @"/usr/local/bin/ffprobe",
        @"/usr/bin/ffprobe",
    ];
}

+ (NSString *)bundledToolPath:(NSString *)name {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:name ofType:nil inDirectory:@"bin"];
    if (path.length == 0 && bundle.resourcePath.length > 0) {
        path = [[bundle.resourcePath stringByAppendingPathComponent:@"bin"] stringByAppendingPathComponent:name];
    }
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
        return path;
    }
    return nil;
}

+ (NSString *)findExecutableInCandidates:(NSArray<NSString *> *)candidates name:(NSString *)name {
    NSString *bundled = [self bundledToolPath:name];
    if (bundled.length > 0) {
        return bundled;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in candidates) {
        if ([fm isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return [fm isExecutableFileAtPath:name] ? name : nil;
}

+ (NSString *)ffmpegPath {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cached = [self findExecutableInCandidates:[self ffmpegCandidates] name:@"ffmpeg"];
    });
    return cached;
}

+ (NSString *)ffprobePath {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cached = [self findExecutableInCandidates:[self ffprobeCandidates] name:@"ffprobe"];
    });
    return cached;
}

+ (BOOL)isAvailable {
    return [self ffmpegPath].length > 0 && [self ffprobePath].length > 0;
}

+ (NSString *)availabilityHint {
    if ([self bundledToolPath:@"ffmpeg"] == nil) {
        return @"未找到内置 ffmpeg。请重新执行 ./build-native-mac.sh 打包；"
               @"开发模式可先 brew install ffmpeg";
    }
    return @"未找到 ffmpeg/ffprobe。请安装：brew install ffmpeg";
}

+ (void)runExecutable:(NSString *)launchPath
            arguments:(NSArray<NSString *> *)arguments
           completion:(void (^)(BOOL ok, NSString *output, NSString *errorText))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = launchPath;
        task.arguments = arguments;
        NSMutableDictionary<NSString *, NSString *> *env =
            [[[NSProcessInfo processInfo] environment] mutableCopy];
        NSString *libDir = [[[launchPath stringByDeletingLastPathComponent]
                              stringByAppendingPathComponent:@"../lib/ffmpeg"] stringByStandardizingPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:libDir]) {
            NSString *existing = env[@"DYLD_LIBRARY_PATH"];
            if (existing.length > 0) {
                env[@"DYLD_LIBRARY_PATH"] = [NSString stringWithFormat:@"%@:%@", libDir, existing];
            } else {
                env[@"DYLD_LIBRARY_PATH"] = libDir;
            }
        }
        task.environment = env;
        NSPipe *outPipe = [NSPipe pipe];
        NSPipe *errPipe = [NSPipe pipe];
        task.standardOutput = outPipe;
        task.standardError = errPipe;
        NSString *errMsg = @"";
        BOOL ok = NO;
        @try {
            [task launch];
            [task waitUntilExit];
            NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
            NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
            NSString *stdoutText = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
            NSString *stderrText = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";
            ok = task.terminationStatus == 0;
            errMsg = stderrText.length > 0 ? stderrText : stdoutText;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(ok, stdoutText, errMsg);
            });
            return;
        } @catch (NSException *exception) {
            errMsg = exception.reason ?: @"无法启动 ffmpeg";
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, @"", errMsg);
        });
    });
}

+ (NSError *)ffmpegMissingError {
    return [NSError errorWithDomain:@"QYPTFFmpegAudio"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: [self availabilityHint]}];
}

+ (NSArray<NSString *> *)codecArgsForFormat:(NSString *)format {
    NSString *fmt = format.lowercaseString;
    if ([fmt isEqualToString:@"wav"]) {
        return @[@"-acodec", @"pcm_s16le"];
    }
    if ([fmt isEqualToString:@"m4a"] || [fmt isEqualToString:@"aac"]) {
        return @[@"-acodec", @"aac", @"-b:a", @"192k"];
    }
    return @[@"-acodec", @"libmp3lame", @"-q:a", @"2"];
}

+ (void)probeDurationForFile:(NSString *)inputPath
                  completion:(void (^)(NSTimeInterval, NSError * _Nullable))completion {
    NSString *ffprobe = [self ffprobePath];
    if (!ffprobe) {
        completion(0, [self ffmpegMissingError]);
        return;
    }
    NSArray *args = @[
        @"-v", @"error",
        @"-show_entries", @"format=duration",
        @"-of", @"default=noprint_wrappers=1:nokey=1",
        inputPath,
    ];
    [self runExecutable:ffprobe arguments:args completion:^(BOOL ok, NSString *output, NSString *errorText) {
        if (!ok) {
            completion(0, [NSError errorWithDomain:@"QYPTFFmpegAudio" code:2 userInfo:@{
                NSLocalizedDescriptionKey: errorText.length > 0 ? errorText : @"无法读取时长",
            }]);
            return;
        }
        double value = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].doubleValue;
        completion(value > 0 ? value : 0, nil);
    }];
}

+ (void)extractAudioFromVideo:(NSString *)videoPath
                   outputPath:(NSString *)outputPath
                       format:(NSString *)format
                   completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSString *ffmpeg = [self ffmpegPath];
    if (!ffmpeg) {
        completion(nil, [self ffmpegMissingError]);
        return;
    }
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-y", @"-i", videoPath, @"-vn", nil];
    [args addObjectsFromArray:[self codecArgsForFormat:format]];
    [args addObject:outputPath];
    [self runExecutable:ffmpeg arguments:args completion:^(BOOL ok, NSString *output, NSString *errorText) {
        (void)output;
        if (!ok) {
            completion(nil, [NSError errorWithDomain:@"QYPTFFmpegAudio" code:3 userInfo:@{
                NSLocalizedDescriptionKey: errorText.length > 0 ? errorText : @"提取音频失败",
            }]);
            return;
        }
        completion(outputPath, nil);
    }];
}

+ (void)trimAudioAtPath:(NSString *)inputPath
             outputPath:(NSString *)outputPath
                  start:(NSString *)startTime
                    end:(NSString *)endTime
             completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSString *ffmpeg = [self ffmpegPath];
    if (!ffmpeg) {
        completion(nil, [self ffmpegMissingError]);
        return;
    }
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @"-y", @"-i", inputPath,
                            @"-ss", startTime,
                            @"-to", endTime,
                            @"-vn", nil];
    NSString *ext = outputPath.pathExtension.lowercaseString;
    [args addObjectsFromArray:[self codecArgsForFormat:ext.length > 0 ? ext : @"mp3"]];
    [args addObject:outputPath];
    [self runExecutable:ffmpeg arguments:args completion:^(BOOL ok, NSString *output, NSString *errorText) {
        (void)output;
        if (!ok) {
            completion(nil, [NSError errorWithDomain:@"QYPTFFmpegAudio" code:4 userInfo:@{
                NSLocalizedDescriptionKey: errorText.length > 0 ? errorText : @"剪辑失败",
            }]);
            return;
        }
        completion(outputPath, nil);
    }];
}

+ (void)exportAudioAtPath:(NSString *)inputPath
               outputPath:(NSString *)outputPath
                   format:(NSString *)format
               completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    NSString *ffmpeg = [self ffmpegPath];
    if (!ffmpeg) {
        completion(nil, [self ffmpegMissingError]);
        return;
    }
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-y", @"-i", inputPath, @"-vn", nil];
    [args addObjectsFromArray:[self codecArgsForFormat:format]];
    [args addObject:outputPath];
    [self runExecutable:ffmpeg arguments:args completion:^(BOOL ok, NSString *output, NSString *errorText) {
        (void)output;
        if (!ok) {
            completion(nil, [NSError errorWithDomain:@"QYPTFFmpegAudio" code:5 userInfo:@{
                NSLocalizedDescriptionKey: errorText.length > 0 ? errorText : @"导出失败",
            }]);
            return;
        }
        completion(outputPath, nil);
    }];
}

+ (NSString *)formatTime:(NSTimeInterval)seconds {
    if (seconds < 0 || isnan(seconds) || isinf(seconds)) {
        seconds = 0;
    }
    int totalMs = (int)round(seconds * 100.0);
    int cs = totalMs % 100;
    int totalSec = totalMs / 100;
    int s = totalSec % 60;
    int m = (totalSec / 60) % 60;
    int h = totalSec / 3600;
    if (h > 0) {
        return [NSString stringWithFormat:@"%02d:%02d:%02d.%02d", h, m, s, cs];
    }
    return [NSString stringWithFormat:@"%02d:%02d.%02d", m, s, cs];
}

@end
