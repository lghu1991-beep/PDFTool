#import "QYPTHubWindowController.h"

@interface QYPTHubCardView : NSView
@property (nonatomic, assign) NSInteger cardTag;
@property (nonatomic, copy) void (^onClick)(NSInteger tag);
@end

@implementation QYPTHubCardView

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5) xRadius:12 yRadius:12];
    [[NSColor whiteColor] setFill];
    [path fill];
    [[NSColor colorWithCalibratedWhite:0.85 alpha:1] setStroke];
    path.lineWidth = 1;
    [path stroke];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    if (self.onClick) {
        self.onClick(self.cardTag);
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

@end

@interface QYPTHubWindowController ()
@property (nonatomic, copy) void (^onOpenPDF)(void);
@property (nonatomic, copy) void (^onOpenAudio)(void);
@end

@implementation QYPTHubWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 380)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"工具集";
    window.minSize = NSMakeSize(520, 320);
    self = [super initWithWindow:window];
    if (self) {
        [self buildUI];
    }
    return self;
}

- (void)setOpenPDFHandler:(void (^)(void))handler {
    _onOpenPDF = [handler copy];
}

- (void)setOpenAudioHandler:(void (^)(void))handler {
    _onOpenAudio = [handler copy];
}

- (void)buildUI {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;
    content.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.97 alpha:1.0].CGColor;

    NSTextField *title = [self label:@"工具集" frame:NSMakeRect(0, 300, 640, 40)];
    title.font = [NSFont boldSystemFontOfSize:28];
    title.alignment = NSTextAlignmentCenter;
    title.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin;
    [content addSubview:title];

    NSTextField *subtitle = [self label:@"选择要使用的工具" frame:NSMakeRect(0, 272, 640, 22)];
    subtitle.font = [NSFont systemFontOfSize:14];
    subtitle.textColor = [NSColor secondaryLabelColor];
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin;
    [content addSubview:subtitle];

    __weak typeof(self) weakSelf = self;
    [self addCardInView:content
                  frame:NSMakeRect(48, 88, 260, 160)
                    tag:1
                  title:@"PDF 工具"
               features:@"Word 转 PDF · 水印 · 压缩 · 合并 · 拆分"
                onClick:^(NSInteger tag) {
        if (tag == 1) weakSelf.onOpenPDF();
    }];
    [self addCardInView:content
                  frame:NSMakeRect(332, 88, 260, 160)
                    tag:2
                  title:@"MP3 / 音频编辑"
               features:@"提取 · 剪辑 · 导出"
                onClick:^(NSInteger tag) {
        if (tag == 2) weakSelf.onOpenAudio();
    }];

    NSTextField *footer = [self label:@"关闭此窗口将退出应用" frame:NSMakeRect(0, 24, 640, 18)];
    footer.font = [NSFont systemFontOfSize:11];
    footer.textColor = [NSColor tertiaryLabelColor];
    footer.alignment = NSTextAlignmentCenter;
    footer.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [content addSubview:footer];
}

- (void)addCardInView:(NSView *)parent
                frame:(NSRect)frame
                  tag:(NSInteger)tag
                title:(NSString *)title
             features:(NSString *)features
              onClick:(void (^)(NSInteger tag))onClick {
    QYPTHubCardView *card = [[QYPTHubCardView alloc] initWithFrame:frame];
    card.cardTag = tag;
    card.onClick = onClick;
    card.autoresizingMask = (tag == 1) ? (NSViewMaxXMargin | NSViewMinYMargin) : (NSViewMinXMargin | NSViewMinYMargin);
    [parent addSubview:card];

    NSTextField *feat = [self label:features frame:NSMakeRect(16, frame.size.height - 56, frame.size.width - 32, 40)];
    feat.font = [NSFont systemFontOfSize:12];
    feat.textColor = [NSColor secondaryLabelColor];
    feat.alignment = NSTextAlignmentLeft;
    feat.maximumNumberOfLines = 2;
    [card addSubview:feat];

    NSTextField *name = [self label:title frame:NSMakeRect(16, 20, frame.size.width - 32, 32)];
    name.font = [NSFont boldSystemFontOfSize:18];
    name.alignment = NSTextAlignmentLeft;
    [card addSubview:name];
}

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.stringValue = text;
    field.editable = NO;
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.selectable = NO;
    return field;
}

@end
