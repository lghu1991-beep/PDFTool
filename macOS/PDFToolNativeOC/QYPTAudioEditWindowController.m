#import "QYPTAudioEditWindowController.h"
#import "QYPTFFmpegAudio.h"
#import <AVFoundation/AVFoundation.h>

static NSColor *QYPTAudioBgColor(void) {
    return [NSColor colorWithCalibratedRed:0.91 green:0.95 blue:0.99 alpha:1.0];
}

static NSColor *QYPTAudioBarColor(void) {
    return [NSColor colorWithCalibratedRed:0.40 green:0.58 blue:0.82 alpha:1.0];
}

static NSColor *QYPTAudioTitleColor(void) {
    return [NSColor colorWithCalibratedRed:0.10 green:0.22 blue:0.48 alpha:1.0];
}

#pragma mark - Drop zone（整页可拖放，无虚线框）

@interface QYPTAudioDropView : NSView <NSDraggingDestination>
@property (nonatomic, copy) void (^onFilesDropped)(NSArray<NSString *> *paths);
@end

@implementation QYPTAudioDropView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = sender.draggingPasteboard;
    NSArray *items = [pb readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *url in items) {
        if (url.isFileURL) {
            [paths addObject:url.path];
        }
    }
    if (paths.count > 0 && self.onFilesDropped) {
        self.onFilesDropped(paths);
        return YES;
    }
    return NO;
}

@end

#pragma mark - Window controller

@interface QYPTAudioEditWindowController () <NSWindowDelegate>
@property (nonatomic, strong) NSView *bodyView;
@property (nonatomic, strong) QYPTAudioDropView *dropView;
@property (nonatomic, strong) NSView *actionBar;
@property (nonatomic, strong) NSTextField *dropHintLabel;
@property (nonatomic, strong) NSTextField *fileNameLabel;
@property (nonatomic, strong) NSView *trimPanel;
@property (nonatomic, strong) NSTextField *trimStartField;
@property (nonatomic, strong) NSTextField *trimEndField;
@property (nonatomic, strong) NSButton *trimButton;
@property (nonatomic, strong) NSTextField *timeLabel;
@property (nonatomic, strong) NSButton *playButton;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSPopUpButton *formatPop;
@property (nonatomic, strong, nullable) NSString *loadedFilePath;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong, nullable) AVAudioPlayer *player;
@property (nonatomic, strong, nullable) NSTimer *playTimer;
@property (nonatomic, assign) BOOL busy;
@end

@implementation QYPTAudioEditWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 920, 560)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"AudioEdit";
    window.minSize = NSMakeSize(720, 480);
    self = [super initWithWindow:window];
    if (self) {
        _duration = 0;
        self.window.delegate = self;
        [self buildUI];
        if (![QYPTFFmpegAudio isAvailable]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlert:@"需要 ffmpeg" message:[QYPTFFmpegAudio availabilityHint]];
            });
        }
    }
    return self;
}

- (void)dealloc {
    [self stopPlayback];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutContent];
}

- (void)buildUI {
    NSView *root = self.window.contentView;
    const CGFloat footerH = 56;

    self.bodyView = [[NSView alloc] initWithFrame:NSMakeRect(0, footerH, root.bounds.size.width, root.bounds.size.height - footerH)];
    self.bodyView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.bodyView.wantsLayer = YES;
    self.bodyView.layer.backgroundColor = QYPTAudioBgColor().CGColor;
    [root addSubview:self.bodyView];

    NSView *footer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, root.bounds.size.width, footerH)];
    footer.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    footer.wantsLayer = YES;
    footer.layer.backgroundColor = QYPTAudioBarColor().CGColor;
    [root addSubview:footer];

    self.dropView = [[QYPTAudioDropView alloc] initWithFrame:self.bodyView.bounds];
    self.dropView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    __weak typeof(self) weakSelf = self;
    self.dropView.onFilesDropped = ^(NSArray<NSString *> *paths) {
        [weakSelf importMediaAtPath:paths.firstObject];
    };
    [self.bodyView addSubview:self.dropView];

    [self buildActionBar];
    [self buildDropLabels];
    [self buildTrimPanel];
    [self buildFooterInView:footer];
    [self layoutContent];
}

- (void)buildActionBar {
    self.actionBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 52)];
    [self.dropView addSubview:self.actionBar];

    NSButton *extract = [self actionButton:@"从视频中提取音频" tag:1];
    NSButton *addFile = [self actionButton:@"添加文件" tag:2];
    NSButton *record = [self actionButton:@"录音" tag:3];
    [self.actionBar addSubview:extract];
    [self.actionBar addSubview:addFile];
    [self.actionBar addSubview:record];

    NSTextField *badge = [self label:@"NEW" frame:NSMakeRect(0, 0, 36, 16)];
    badge.font = [NSFont boldSystemFontOfSize:9];
    badge.textColor = [NSColor whiteColor];
    badge.backgroundColor = [NSColor colorWithCalibratedRed:0.22 green:0.72 blue:0.42 alpha:1];
    badge.drawsBackground = YES;
    badge.alignment = NSTextAlignmentCenter;
    badge.wantsLayer = YES;
    badge.layer.cornerRadius = 3;
    badge.tag = 9001;
    [record addSubview:badge];
}

- (void)buildDropLabels {
    self.dropHintLabel = [self label:@"或拖放这里" frame:NSZeroRect];
    self.dropHintLabel.font = [NSFont systemFontOfSize:15];
    self.dropHintLabel.textColor = [NSColor secondaryLabelColor];
    self.dropHintLabel.alignment = NSTextAlignmentCenter;
    [self.dropView addSubview:self.dropHintLabel];

    self.fileNameLabel = [self label:@"" frame:NSZeroRect];
    self.fileNameLabel.font = [NSFont systemFontOfSize:13];
    self.fileNameLabel.textColor = QYPTAudioTitleColor();
    self.fileNameLabel.alignment = NSTextAlignmentCenter;
    self.fileNameLabel.hidden = YES;
    [self.dropView addSubview:self.fileNameLabel];
}

- (void)buildTrimPanel {
    self.trimPanel = [[NSView alloc] initWithFrame:NSZeroRect];
    self.trimPanel.hidden = YES;
    [self.dropView addSubview:self.trimPanel];

    NSTextField *trimTitle = [self label:@"剪辑片段" frame:NSMakeRect(0, 36, 80, 20)];
    trimTitle.font = [NSFont boldSystemFontOfSize:12];
    trimTitle.textColor = QYPTAudioTitleColor();
    [self.trimPanel addSubview:trimTitle];

    [self.trimPanel addSubview:[self label:@"开始" frame:NSMakeRect(0, 8, 36, 20)]];
    self.trimStartField = [self editableField:@"0" frame:NSMakeRect(40, 6, 100, 24)];
    [self.trimPanel addSubview:self.trimStartField];

    [self.trimPanel addSubview:[self label:@"结束" frame:NSMakeRect(156, 8, 36, 20)]];
    self.trimEndField = [self editableField:@"" frame:NSMakeRect(196, 6, 100, 24)];
    [self.trimPanel addSubview:self.trimEndField];

    self.trimButton = [[NSButton alloc] initWithFrame:NSMakeRect(310, 4, 88, 28)];
    self.trimButton.title = @"应用剪辑";
    self.trimButton.bezelStyle = NSBezelStyleRounded;
    self.trimButton.target = self;
    self.trimButton.action = @selector(applyTrim);
    [self.trimPanel addSubview:self.trimButton];
}

- (void)layoutContent {
    NSRect bounds = self.dropView.bounds;
    CGFloat w = bounds.size.width;
    CGFloat margin = 24;
    CGFloat btnH = 48;
    CGFloat btnGap = 16;
    CGFloat btnW = MIN(240, (w - margin * 2 - btnGap * 2) / 3.0);
    CGFloat barW = btnW * 3 + btnGap * 2;
    CGFloat barX = (w - barW) / 2.0;
    CGFloat barY = 72;

    self.actionBar.frame = NSMakeRect(barX, barY, barW, btnH);
    for (NSView *sub in self.actionBar.subviews) {
        if (![sub isKindOfClass:[NSButton class]]) continue;
        NSButton *btn = (NSButton *)sub;
        NSInteger index = btn.tag - 1;
        if (index < 0) continue;
        btn.frame = NSMakeRect(index * (btnW + btnGap), 0, btnW, btnH);
        if (btn.tag == 3) {
            for (NSView *child in btn.subviews) {
                if (child.tag == 9001) {
                    child.frame = NSMakeRect(btnW - 38, btnH - 18, 36, 16);
                }
            }
        }
    }

    self.dropHintLabel.frame = NSMakeRect(margin, barY + btnH + 20, w - margin * 2, 24);
    self.fileNameLabel.frame = NSMakeRect(margin, barY + btnH + 48, w - margin * 2, 20);

    CGFloat trimW = MIN(420, w - margin * 2);
    self.trimPanel.frame = NSMakeRect((w - trimW) / 2.0, bounds.size.height - 88, trimW, 64);
}

- (void)buildFooterInView:(NSView *)footer {
    self.playButton = [[NSButton alloc] initWithFrame:NSMakeRect(18, 12, 32, 32)];
    self.playButton.title = @"▶";
    self.playButton.bezelStyle = NSBezelStyleCircular;
    self.playButton.font = [NSFont systemFontOfSize:13];
    self.playButton.wantsLayer = YES;
    self.playButton.layer.backgroundColor = [NSColor whiteColor].CGColor;
    self.playButton.contentTintColor = QYPTAudioBarColor();
    self.playButton.target = self;
    self.playButton.action = @selector(playTapped);
    self.playButton.enabled = NO;
    [footer addSubview:self.playButton];

    self.timeLabel = [self label:@"00:00.00 / 00:00.00" frame:NSMakeRect(58, 16, 220, 22)];
    self.timeLabel.textColor = [NSColor whiteColor];
    self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    [footer addSubview:self.timeLabel];

    NSTextField *fmtLabel = [self label:@"格式:" frame:NSMakeRect(footer.bounds.size.width - 200, 18, 42, 20)];
    fmtLabel.textColor = [NSColor whiteColor];
    fmtLabel.autoresizingMask = NSViewMinXMargin;
    [footer addSubview:fmtLabel];

    self.formatPop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(footer.bounds.size.width - 152, 14, 72, 26) pullsDown:NO];
    [self.formatPop addItemsWithTitles:@[@"mp3", @"m4a", @"wav", @"aac"]];
    self.formatPop.autoresizingMask = NSViewMinXMargin;
    [footer addSubview:self.formatPop];

    self.saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(footer.bounds.size.width - 76, 12, 64, 30)];
    self.saveButton.title = @"保存";
    self.saveButton.bezelStyle = NSBezelStyleRounded;
    self.saveButton.target = self;
    self.saveButton.action = @selector(saveTapped);
    self.saveButton.enabled = NO;
    self.saveButton.autoresizingMask = NSViewMinXMargin;
    self.saveButton.wantsLayer = YES;
    self.saveButton.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1 alpha:0.35].CGColor;
    self.saveButton.layer.cornerRadius = 6;
    [footer addSubview:self.saveButton];
    [self updateSaveButtonStyle];
}

- (void)updateSaveButtonStyle {
    if (self.saveButton.enabled) {
        self.saveButton.alphaValue = 1.0;
        self.saveButton.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1 alpha:0.9].CGColor;
    } else {
        self.saveButton.alphaValue = 0.45;
        self.saveButton.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1 alpha:0.2].CGColor;
    }
}

#pragma mark - Media

- (BOOL)isVideoPath:(NSString *)path {
    NSString *ext = path.pathExtension.lowercaseString;
    NSSet *video = [NSSet setWithArray:@[@"mp4", @"mov", @"mkv", @"avi", @"webm", @"m4v", @"flv", @"wmv"]];
    return [video containsObject:ext];
}

- (void)importMediaAtPath:(NSString *)path {
    if (path.length == 0) return;
    if ([self isVideoPath:path]) {
        [self extractFromVideo:path];
        return;
    }
    [self loadAudioAtPath:path];
}

- (void)loadAudioAtPath:(NSString *)path {
    if (path.length == 0) return;
    [self stopPlayback];
    self.loadedFilePath = path;
    self.dropHintLabel.hidden = YES;
    self.fileNameLabel.stringValue = path.lastPathComponent;
    self.fileNameLabel.hidden = NO;
    self.trimPanel.hidden = NO;
    self.playButton.enabled = YES;
    self.saveButton.enabled = YES;
    [self updateSaveButtonStyle];
    self.duration = 0;
    self.trimStartField.stringValue = @"0";
    self.trimEndField.stringValue = @"";
    self.timeLabel.stringValue = @"00:00.00 / --:--.--";

    __weak typeof(self) weakSelf = self;
    [QYPTFFmpegAudio probeDurationForFile:path completion:^(NSTimeInterval duration, NSError *error) {
        if (error) {
            [weakSelf showAlert:@"提示" message:error.localizedDescription];
            return;
        }
        weakSelf.duration = duration;
        weakSelf.trimEndField.stringValue = [QYPTFFmpegAudio formatTime:duration];
        [weakSelf updateTimeLabelWithCurrent:0];
    }];
}

- (void)extractFromVideo:(NSString *)videoPath {
    if (![QYPTFFmpegAudio isAvailable]) {
        [self showAlert:@"需要 ffmpeg" message:[QYPTFFmpegAudio availabilityHint]];
        return;
    }
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString *ext = self.formatPop.titleOfSelectedItem ?: @"mp3";
    panel.allowedFileTypes = @[ext];
    panel.nameFieldStringValue = [[videoPath.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
    if ([panel runModal] != NSModalResponseOK) return;

    [self setBusy:YES status:@"正在从视频提取音频…"];
    __weak typeof(self) weakSelf = self;
    [QYPTFFmpegAudio extractAudioFromVideo:videoPath
                                outputPath:panel.URL.path
                                    format:ext
                                completion:^(NSString *outputPath, NSError *error) {
        [weakSelf setBusy:NO status:@""];
        if (error) {
            [weakSelf showAlert:@"提取失败" message:error.localizedDescription];
            return;
        }
        [weakSelf loadAudioAtPath:outputPath];
        [weakSelf showAlert:@"完成" message:[NSString stringWithFormat:@"已提取到：\n%@", outputPath]];
    }];
}

- (void)applyTrim {
    if (self.loadedFilePath.length == 0) return;
    if (![QYPTFFmpegAudio isAvailable]) {
        [self showAlert:@"需要 ffmpeg" message:[QYPTFFmpegAudio availabilityHint]];
        return;
    }
    NSString *start = self.trimStartField.stringValue;
    NSString *end = self.trimEndField.stringValue;
    if (start.length == 0 || end.length == 0) {
        [self showAlert:@"提示" message:@"请填写剪辑开始与结束时间"];
        return;
    }
    NSString *ext = self.loadedFilePath.pathExtension.length > 0 ? self.loadedFilePath.pathExtension : @"mp3";
    NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [[NSUUID UUID].UUIDString stringByAppendingPathExtension:ext]];
    [self setBusy:YES status:@"正在剪辑…"];
    __weak typeof(self) weakSelf = self;
    [QYPTFFmpegAudio trimAudioAtPath:self.loadedFilePath
                          outputPath:temp
                               start:start
                                 end:end
                          completion:^(NSString *outputPath, NSError *error) {
        [weakSelf setBusy:NO status:@""];
        if (error) {
            [weakSelf showAlert:@"剪辑失败" message:error.localizedDescription];
            return;
        }
        [weakSelf loadAudioAtPath:outputPath];
        [weakSelf showAlert:@"完成" message:@"剪辑已应用。"];
    }];
}

- (void)saveTapped {
    if (self.loadedFilePath.length == 0) return;
    if (![QYPTFFmpegAudio isAvailable]) {
        [self showAlert:@"需要 ffmpeg" message:[QYPTFFmpegAudio availabilityHint]];
        return;
    }
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString *ext = self.formatPop.titleOfSelectedItem ?: @"mp3";
    panel.allowedFileTypes = @[ext];
    panel.nameFieldStringValue = [[self.loadedFilePath.lastPathComponent stringByDeletingPathExtension]
                                  stringByAppendingPathExtension:ext];
    if ([panel runModal] != NSModalResponseOK) return;

    [self setBusy:YES status:@"正在导出…"];
    __weak typeof(self) weakSelf = self;
    [QYPTFFmpegAudio exportAudioAtPath:self.loadedFilePath
                            outputPath:panel.URL.path
                                format:ext
                            completion:^(NSString *outputPath, NSError *error) {
        [weakSelf setBusy:NO status:@""];
        if (error) {
            [weakSelf showAlert:@"导出失败" message:error.localizedDescription];
            return;
        }
        [weakSelf showAlert:@"完成" message:[NSString stringWithFormat:@"已保存到：\n%@", outputPath]];
    }];
}

#pragma mark - Playback

- (void)playTapped {
    if (self.player.isPlaying) {
        [self stopPlayback];
        self.playButton.title = @"▶";
        return;
    }
    if (self.loadedFilePath.length == 0) return;
    NSError *error = nil;
    NSURL *url = [NSURL fileURLWithPath:self.loadedFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error || !self.player) {
        [self showAlert:@"无法播放" message:error.localizedDescription ?: @"未知错误"];
        return;
    }
    [self.player play];
    self.playButton.title = @"■";
    __weak typeof(self) weakSelf = self;
    self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf updateTimeLabelWithCurrent:weakSelf.player.currentTime];
        if (!weakSelf.player.isPlaying) {
            [weakSelf stopPlayback];
            weakSelf.playButton.title = @"▶";
        }
    }];
}

- (void)stopPlayback {
    [self.playTimer invalidate];
    self.playTimer = nil;
    [self.player stop];
    self.player = nil;
}

- (void)updateTimeLabelWithCurrent:(NSTimeInterval)current {
    NSString *cur = [QYPTFFmpegAudio formatTime:current];
    NSString *total = self.duration > 0 ? [QYPTFFmpegAudio formatTime:self.duration] : @"--:--.--";
    self.timeLabel.stringValue = [NSString stringWithFormat:@"%@ / %@", cur, total];
}

#pragma mark - Actions

- (void)actionTapped:(NSButton *)sender {
    if (sender.tag == 1) {
        [self pickVideoFile];
    } else if (sender.tag == 2) {
        [self pickMediaFile];
    } else if (sender.tag == 3) {
        [self showAlert:@"提示" message:@"录音功能开发中，可先使用「添加文件」或拖放导入。"];
    }
}

- (void)pickVideoFile {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"mp4", @"mov", @"mkv", @"avi", @"webm", @"m4v"];
    if ([panel runModal] == NSModalResponseOK) {
        [self extractFromVideo:panel.URL.path];
    }
}

- (void)pickMediaFile {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"mp3", @"m4a", @"wav", @"aac", @"flac", @"aiff", @"caf", @"mp4", @"mov", @"mkv"];
    if ([panel runModal] == NSModalResponseOK) {
        [self importMediaAtPath:panel.URL.path];
    }
}

- (void)resetWorkspace {
    [self stopPlayback];
    self.loadedFilePath = nil;
    self.duration = 0;
    self.dropHintLabel.hidden = NO;
    self.dropHintLabel.stringValue = @"或拖放这里";
    self.fileNameLabel.hidden = YES;
    self.trimPanel.hidden = YES;
    self.playButton.enabled = NO;
    self.playButton.title = @"▶";
    self.saveButton.enabled = NO;
    [self updateSaveButtonStyle];
    self.trimStartField.stringValue = @"0";
    self.trimEndField.stringValue = @"";
    self.timeLabel.stringValue = @"00:00.00 / 00:00.00";
}

- (void)setBusy:(BOOL)busy status:(NSString *)status {
    self.busy = busy;
    self.window.title = busy ? [NSString stringWithFormat:@"AudioEdit - %@", status] : @"AudioEdit";
    self.saveButton.enabled = !busy && self.loadedFilePath.length > 0;
    self.playButton.enabled = !busy && self.loadedFilePath.length > 0;
    self.trimButton.enabled = !busy && self.loadedFilePath.length > 0;
    [self updateSaveButtonStyle];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:@"好"];
    [alert runModal];
}

#pragma mark - UI helpers

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.stringValue = text;
    field.editable = NO;
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.selectable = NO;
    return field;
}

- (NSTextField *)editableField:(NSString *)text frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.stringValue = text;
    field.editable = YES;
    field.bezeled = YES;
    return field;
}

- (NSButton *)actionButton:(NSString *)title tag:(NSInteger)tag {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSZeroRect];
    btn.title = title;
    btn.tag = tag;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    btn.contentTintColor = QYPTAudioTitleColor();
    btn.target = self;
    btn.action = @selector(actionTapped:);
    btn.wantsLayer = YES;
    btn.layer.backgroundColor = [NSColor whiteColor].CGColor;
    btn.layer.cornerRadius = 10;
    btn.layer.borderWidth = 0;
    return btn;
}

@end
