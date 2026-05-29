#import "QYPTEngineClient.h"

NSString * const QYPTEngineErrorDomain = @"QYPTEngineErrorDomain";

@implementation QYPTEngineClient

+ (void)runCommand:(NSString *)command
         arguments:(NSArray<NSString *> *)arguments
        completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSDictionary *data = [self syncRunCommand:command arguments:arguments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(data, error);
        });
    });
}

+ (NSDictionary *)syncRunCommand:(NSString *)command
                       arguments:(NSArray<NSString *> *)arguments
                           error:(NSError **)error {
    NSString *executable = nil;
    NSMutableArray<NSString *> *prefixArgs = [NSMutableArray array];
    if (![self resolveEngineExecutable:&executable prefixArgs:prefixArgs error:error]) {
        return nil;
    }

    NSMutableArray<NSString *> *allArgs = [prefixArgs mutableCopy];
    [allArgs addObject:command];
    [allArgs addObjectsFromArray:arguments];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = executable;
    task.arguments = allArgs;
    task.environment = [NSProcessInfo processInfo].environment;

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;

    @try {
        [task launch];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:QYPTEngineErrorDomain
                                         code:QYPTEngineErrorNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"无法启动引擎"}];
        }
        return nil;
    }
    [task waitUntilExit];

    NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    NSString *stdoutText = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
    NSString *stderrText = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";

    NSString *lastLine = stdoutText;
    NSRange lastNL = [stdoutText rangeOfString:@"\n" options:NSBackwardsSearch];
    if (lastNL.location != NSNotFound && lastNL.location + 1 < stdoutText.length) {
        lastLine = [stdoutText substringFromIndex:lastNL.location + 1];
    }
    lastLine = [lastLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSData *jsonData = [lastLine dataUsingEncoding:NSUTF8StringEncoding];
    id rootObj = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
    if (![rootObj isKindOfClass:[NSDictionary class]]) {
        NSString *hint = stderrText.length > 0 ? stderrText : stdoutText;
        if (error) {
            *error = [NSError errorWithDomain:QYPTEngineErrorDomain
                                         code:QYPTEngineErrorBadResponse
                                     userInfo:@{NSLocalizedDescriptionKey: hint.length > 0 ? hint : @"引擎无有效输出"}];
        }
        return nil;
    }
    NSDictionary *root = (NSDictionary *)rootObj;
    BOOL ok = [root[@"ok"] boolValue];
    if (!ok) {
        NSString *msg = root[@"error"];
        if (![msg isKindOfClass:[NSString class]] || msg.length == 0) {
            msg = @"未知错误";
        }
        if (error) {
            *error = [NSError errorWithDomain:QYPTEngineErrorDomain
                                         code:QYPTEngineErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }
    id data = root[@"data"];
    return [data isKindOfClass:[NSDictionary class]] ? (NSDictionary *)data : @{};
}

+ (BOOL)resolveEngineExecutable:(NSString **)executable
                     prefixArgs:(NSMutableArray<NSString *> *)prefixArgs
                          error:(NSError **)error {
    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"PDFToolEngine" ofType:nil];
    if (bundled.length > 0 && [[NSFileManager defaultManager] isExecutableFileAtPath:bundled]) {
        *executable = bundled;
        return YES;
    }

    NSString *envRoot = [NSProcessInfo processInfo].environment[@"PDFTOOL_ROOT"];
    if (envRoot.length > 0) {
        NSString *cli = [envRoot stringByAppendingPathComponent:@"src/engine_cli.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cli]) {
            NSString *python = [self python3Path];
            if (python) {
                *executable = python;
                [prefixArgs addObject:cli];
                return YES;
            }
        }
    }

    NSString *repoRoot = [self findRepoRoot];
    if (repoRoot) {
        NSString *cli = [repoRoot stringByAppendingPathComponent:@"src/engine_cli.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:cli]) {
            NSString *python = [self python3Path];
            if (python) {
                *executable = python;
                [prefixArgs addObject:cli];
                return YES;
            }
        }
    }

    if (error) {
        *error = [NSError errorWithDomain:QYPTEngineErrorDomain
                                     code:QYPTEngineErrorNotFound
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"未找到 PDF 处理引擎。请先执行 ./build-native-mac.sh 打包，"
                                                @"或设置 PDFTOOL_ROOT 后用 ./run-native-mac.sh 运行。"}];
    }
    return NO;
}

+ (NSString *)python3Path {
    NSArray<NSString *> *candidates = @[
        @"/opt/homebrew/bin/python3",
        @"/usr/local/bin/python3",
        @"/usr/bin/python3",
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in candidates) {
        if ([fm isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return nil;
}

+ (NSString *)findRepoRoot {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *url = [NSBundle mainBundle].bundleURL;
    for (NSInteger i = 0; i < 8; i++) {
        NSString *cli = [[url URLByAppendingPathComponent:@"src/engine_cli.py"] path];
        if ([fm fileExistsAtPath:cli]) {
            return url.path;
        }
        NSURL *parent = [url URLByDeletingLastPathComponent];
        if ([parent.path isEqualToString:url.path]) {
            break;
        }
        url = parent;
    }
    NSString *cwd = [fm currentDirectoryPath];
    NSString *cli = [cwd stringByAppendingPathComponent:@"src/engine_cli.py"];
    if ([fm fileExistsAtPath:cli]) {
        return cwd;
    }
    return nil;
}

@end
