#import "QYPTMainWindowController.h"
#import "QYPTEngineClient.h"
#import <objc/runtime.h>

@interface QYPTMainWindowController () <NSTableViewDataSource>
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSProgressIndicator *busyIndicator;
@property (nonatomic, assign) BOOL busy;

// Word
@property (nonatomic, strong) NSTextField *wordInputField;
@property (nonatomic, strong) NSTextField *wordOutputField;

// Watermark
@property (nonatomic, strong) NSTextField *wmInputField;
@property (nonatomic, strong) NSTextField *wmOutputField;
@property (nonatomic, assign) BOOL wmTextMode;
@property (nonatomic, strong) NSButton *wmTextRadio;
@property (nonatomic, strong) NSButton *wmImageRadio;
@property (nonatomic, strong) NSBox *wmTextBox;
@property (nonatomic, strong) NSBox *wmImageBox;
@property (nonatomic, strong) NSTextField *wmTextField;
@property (nonatomic, strong) NSTextField *wmAngleField;
@property (nonatomic, strong) NSTextField *wmFontField;
@property (nonatomic, strong) NSPopUpButton *wmTextPositionPop;
@property (nonatomic, strong) NSTextField *wmImagePathField;
@property (nonatomic, strong) NSSlider *wmScaleSlider;
@property (nonatomic, strong) NSPopUpButton *wmImagePositionPop;
@property (nonatomic, strong) NSTextField *wmImgAngleField;
@property (nonatomic, strong) NSSlider *wmOpacitySlider;
@property (nonatomic, strong) NSPopUpButton *wmLayoutPop;

// Compress
@property (nonatomic, strong) NSTextField *compressInputField;
@property (nonatomic, strong) NSTextField *compressOutputField;
@property (nonatomic, strong) NSButton *compressLightRadio;
@property (nonatomic, strong) NSButton *compressMediumRadio;
@property (nonatomic, strong) NSButton *compressStrongRadio;

// Merge
@property (nonatomic, strong) NSMutableArray<NSString *> *mergeFiles;
@property (nonatomic, strong) NSTableView *mergeTableView;
@property (nonatomic, strong) NSTextField *mergeOutputField;

// Split
@property (nonatomic, strong) NSTextField *splitInputField;
@property (nonatomic, strong) NSTextField *splitOutputDirField;
@property (nonatomic, assign) BOOL splitEachPage;
@property (nonatomic, strong) NSButton *splitEachRadio;
@property (nonatomic, strong) NSButton *splitRangeRadio;
@property (nonatomic, strong) NSTextField *splitRangeField;
@end

@implementation QYPTMainWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 820, 640)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"PDF 工具";
    window.minSize = NSMakeSize(700, 560);
    self = [super initWithWindow:window];
    if (self) {
        _mergeFiles = [NSMutableArray array];
        _wmTextMode = YES;
        [self buildUI];
    }
    return self;
}

#pragma mark - UI Shell

- (void)buildUI {
    NSView *content = self.window.contentView;
    NSTabView *tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(12, 44, 796, 548)];
    tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [tabView addTabViewItem:[self tabItemWithLabel:@"Word 转 PDF" view:[self buildWordTab]]];
    [tabView addTabViewItem:[self tabItemWithLabel:@"水印" view:[self buildWatermarkTab]]];
    [tabView addTabViewItem:[self tabItemWithLabel:@"PDF 压缩" view:[self buildCompressTab]]];
    [tabView addTabViewItem:[self tabItemWithLabel:@"合并 PDF" view:[self buildMergeTab]]];
    [tabView addTabViewItem:[self tabItemWithLabel:@"拆分 PDF" view:[self buildSplitTab]]];
    [content addSubview:tabView];

    self.busyIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(16, 14, 18, 18)];
    self.busyIndicator.style = NSProgressIndicatorStyleSpinning;
    self.busyIndicator.displayedWhenStopped = NO;
    self.busyIndicator.autoresizingMask = NSViewMaxYMargin | NSViewMinXMargin;
    [content addSubview:self.busyIndicator];

    self.statusLabel = [self label:@"就绪" frame:NSMakeRect(40, 12, 600, 20)];
    self.statusLabel.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [content addSubview:self.statusLabel];

    NSTextField *hint = [self label:@"PDF 工具" frame:NSMakeRect(660, 12, 150, 20)];
    hint.alignment = NSTextAlignmentRight;
    hint.textColor = [NSColor secondaryLabelColor];
    hint.font = [NSFont systemFontOfSize:11];
    hint.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    [content addSubview:hint];
}

- (NSTabViewItem *)tabItemWithLabel:(NSString *)label view:(NSView *)view {
    NSTabViewItem *item = [[NSTabViewItem alloc] init];
    item.label = label;
    item.view = view;
    return item;
}

#pragma mark - Tabs

- (NSView *)buildWordTab {
    NSView *view = [self tabContainer];
    CGFloat y = view.bounds.size.height - 24;
    y = [self addHint:@"支持 .doc / .docx / .wps / .rtf 等。需安装 LibreOffice（推荐）或 Microsoft Word。"
              toView:view y:y];
    self.wordInputField = [self addPathRow:@"源文件" toView:view y:&y pickTag:1001];
    self.wordOutputField = [self addPathRow:@"输出 PDF" toView:view y:&y pickTag:1002 save:YES];
    [self addActionButton:@"开始转换" toView:view y:y - 36 action:@selector(runWordConvert)];
    return view;
}

- (NSView *)buildWatermarkTab {
    NSView *view = [self tabContainer];
    CGFloat y = view.bounds.size.height - 20;
    self.wmInputField = [self addPathRow:@"PDF 文件" toView:view y:&y pickTag:2001];
    self.wmOutputField = [self addPathRow:@"输出 PDF" toView:view y:&y pickTag:2002 save:YES];

    self.wmTextRadio = [self radio:@"文字" tag:1 frame:NSMakeRect(100, y - 22, 60, 22)];
    self.wmImageRadio = [self radio:@"图片" tag:0 frame:NSMakeRect(170, y - 22, 60, 22)];
    self.wmTextRadio.state = NSControlStateValueOn;
    self.wmTextRadio.action = @selector(wmModeChanged:);
    self.wmImageRadio.action = @selector(wmModeChanged:);
    self.wmTextRadio.target = self;
    self.wmImageRadio.target = self;
    [view addSubview:[self label:@"水印类型" frame:NSMakeRect(16, y - 22, 80, 22)]];
    [view addSubview:self.wmTextRadio];
    [view addSubview:self.wmImageRadio];
    y -= 36;

    self.wmTextBox = [self groupBox:@"文字水印设置" inView:view y:&y height:110];
    self.wmTextField = [self fieldInBox:self.wmTextBox label:@"水印文字" value:@"机密" y:72];
    self.wmAngleField = [self fieldInBox:self.wmTextBox label:@"角度" value:@"45" y:44 x:100 width:60];
    self.wmFontField = [self fieldInBox:self.wmTextBox label:@"字号" value:@"48" y:44 x:220 width:60];
    self.wmTextPositionPop = [self popInBox:self.wmTextBox label:@"文字位置" y:16];

    self.wmImageBox = [self groupBox:@"图片水印设置" inView:view y:&y height:110];
    self.wmImageBox.hidden = YES;
    self.wmImagePathField = [self fieldInBox:self.wmImageBox label:@"水印图片" value:@"" y:72];
    NSButton *pickImg = [[NSButton alloc] initWithFrame:NSMakeRect(520, 72, 60, 24)];
    pickImg.title = @"选择…";
    pickImg.bezelStyle = NSBezelStyleRounded;
    pickImg.tag = 2010;
    pickImg.target = self;
    pickImg.action = @selector(pickFile:);
    [self.wmImageBox addSubview:pickImg];
    self.wmScaleSlider = [self sliderInBox:self.wmImageBox label:@"相对大小" y:44 min:0.08 max:0.8 val:0.25];
    self.wmImagePositionPop = [self popInBox:self.wmImageBox label:@"位置" y:16];
    self.wmImgAngleField = [self fieldInBox:self.wmImageBox label:@"角度" value:@"0" y:16 x:400 width:60];

    self.wmOpacitySlider = [self sliderOnView:view label:@"透明度" y:y - 8 min:0.05 max:0.9 val:0.25];
    y -= 40;
    self.wmLayoutPop = [self popOnView:view label:@"铺设模式" y:y - 4];
    [[self.wmLayoutPop itemAtIndex:0] setTitle:@"single"];
    [self.wmLayoutPop addItemsWithTitles:@[@"grid", @"tile"]];
    y -= 36;
    [self addActionButton:@"添加水印" toView:view y:y action:@selector(runWatermark)];
    return view;
}

- (NSView *)buildCompressTab {
    NSView *view = [self tabContainer];
    CGFloat y = view.bounds.size.height - 24;
    y = [self addHint:@"轻/中：流压缩；强：图片重采样或 Ghostscript（若已安装）。" toView:view y:y];
    self.compressInputField = [self addPathRow:@"PDF 文件" toView:view y:&y pickTag:3001];
    self.compressOutputField = [self addPathRow:@"输出 PDF" toView:view y:&y pickTag:3002 save:YES];
    [view addSubview:[self label:@"压缩级别" frame:NSMakeRect(16, y - 28, 80, 24)]];
    self.compressLightRadio = [self radio:@"轻" tag:0 frame:NSMakeRect(100, y - 28, 50, 24)];
    self.compressMediumRadio = [self radio:@"中（推荐）" tag:1 frame:NSMakeRect(160, y - 28, 100, 24)];
    self.compressStrongRadio = [self radio:@"强" tag:2 frame:NSMakeRect(270, y - 28, 50, 24)];
    self.compressMediumRadio.state = NSControlStateValueOn;
    [view addSubview:self.compressLightRadio];
    [view addSubview:self.compressMediumRadio];
    [view addSubview:self.compressStrongRadio];
    y -= 44;
    [self addActionButton:@"开始压缩" toView:view y:y action:@selector(runCompress)];
    return view;
}

- (NSView *)buildMergeTab {
    NSView *view = [self tabContainer];
    CGFloat y = view.bounds.size.height - 24;
    y = [self addHint:@"按列表顺序合并多个 PDF。" toView:view y:y];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, y - 200, 748, 200)];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    self.mergeTableView = [[NSTableView alloc] initWithFrame:scroll.contentView.bounds];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"path"];
    col.title = @"文件";
    col.width = 700;
    [self.mergeTableView addTableColumn:col];
    self.mergeTableView.dataSource = self;
    self.mergeTableView.headerView = nil;
    scroll.documentView = self.mergeTableView;
    [view addSubview:scroll];
    y -= 216;
    NSButton *addBtn = [self smallButton:@"添加文件" frame:NSMakeRect(16, y, 90, 28) action:@selector(mergeAddFiles)];
    NSButton *rmBtn = [self smallButton:@"移除选中" frame:NSMakeRect(112, y, 90, 28) action:@selector(mergeRemoveSelected)];
    NSButton *clrBtn = [self smallButton:@"清空" frame:NSMakeRect(208, y, 60, 28) action:@selector(mergeClear)];
    [view addSubview:addBtn];
    [view addSubview:rmBtn];
    [view addSubview:clrBtn];
    y -= 40;
    self.mergeOutputField = [self addPathRow:@"输出 PDF" toView:view y:&y pickTag:4001 save:YES];
    [self addActionButton:@"合并" toView:view y:y action:@selector(runMerge)];
    return view;
}

- (NSView *)buildSplitTab {
    NSView *view = [self tabContainer];
    CGFloat y = view.bounds.size.height - 20;
    self.splitInputField = [self addPathRow:@"PDF 文件" toView:view y:&y pickTag:5001];
    self.splitOutputDirField = [self addPathRow:@"输出目录" toView:view y:&y pickTag:5002 save:NO directory:YES];
    self.splitRangeRadio = [self radio:@"按页码范围" tag:0 frame:NSMakeRect(100, y - 22, 120, 22)];
    self.splitEachRadio = [self radio:@"每页单独一个 PDF" tag:1 frame:NSMakeRect(230, y - 22, 160, 22)];
    self.splitRangeRadio.state = NSControlStateValueOn;
    [view addSubview:[self label:@"拆分方式" frame:NSMakeRect(16, y - 22, 80, 22)]];
    [view addSubview:self.splitRangeRadio];
    [view addSubview:self.splitEachRadio];
    y -= 36;
    self.splitRangeField = [self fieldOnView:view label:@"页码范围" value:@"1-1" y:y - 4];
    y -= 36;
    [self addActionButton:@"拆分" toView:view y:y action:@selector(runSplit)];
    return view;
}

#pragma mark - UI Helpers

- (NSView *)tabContainer {
    return [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 780, 520)];
}

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    return label;
}

- (NSTextField *)addPathRow:(NSString *)label
                     toView:(NSView *)view
                          y:(CGFloat *)y
                    pickTag:(NSInteger)tag {
    return [self addPathRow:label toView:view y:y pickTag:tag save:NO directory:NO];
}

- (NSTextField *)addPathRow:(NSString *)label
                     toView:(NSView *)view
                          y:(CGFloat *)y
                    pickTag:(NSInteger)tag
                       save:(BOOL)save {
    return [self addPathRow:label toView:view y:y pickTag:tag save:save directory:NO];
}

- (NSTextField *)addPathRow:(NSString *)label
                     toView:(NSView *)view
                          y:(CGFloat *)y
                    pickTag:(NSInteger)tag
                       save:(BOOL)save
                  directory:(BOOL)directory {
    [view addSubview:[self label:label frame:NSMakeRect(16, *y - 24, 80, 24)]];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(100, *y - 24, 560, 24)];
    field.autoresizingMask = NSViewWidthSizable;
    [view addSubview:field];
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(670, *y - 24, 72, 24)];
    btn.title = @"选择…";
    btn.bezelStyle = NSBezelStyleRounded;
    btn.tag = tag;
    btn.target = self;
    btn.action = @selector(pickFile:);
    objc_setAssociatedObject(btn, "save", @(save), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(btn, "directory", @(directory), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(btn, "field", field, OBJC_ASSOCIATION_ASSIGN);
    [view addSubview:btn];
    *y -= 36;
    return field;
}

- (CGFloat)addHint:(NSString *)text toView:(NSView *)view y:(CGFloat)y {
    NSTextField *hint = [self label:text frame:NSMakeRect(16, y - 40, 740, 36)];
    hint.textColor = [NSColor secondaryLabelColor];
    hint.font = [NSFont systemFontOfSize:12];
    [view addSubview:hint];
    return y - 48;
}

- (void)addActionButton:(NSString *)title toView:(NSView *)view y:(CGFloat)y action:(SEL)action {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(640, y, 100, 32)];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.keyEquivalent = @"\r";
    btn.target = self;
    btn.action = action;
    [view addSubview:btn];
}

- (NSButton *)smallButton:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *btn = [[NSButton alloc] initWithFrame:frame];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = self;
    btn.action = action;
    return btn;
}

- (NSButton *)radio:(NSString *)title tag:(NSInteger)tag frame:(NSRect)frame {
    NSButton *btn = [[NSButton alloc] initWithFrame:frame];
    btn.buttonType = NSButtonTypeRadio;
    btn.title = title;
    btn.tag = tag;
    btn.state = NSControlStateValueOff;
    return btn;
}

- (NSBox *)groupBox:(NSString *)title inView:(NSView *)view y:(CGFloat *)y height:(CGFloat)height {
    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(16, *y - height, 748, height)];
    box.title = title;
    box.boxType = NSBoxPrimary;
    [view addSubview:box];
    *y -= height + 8;
    return box;
}

- (NSTextField *)fieldInBox:(NSBox *)box label:(NSString *)label value:(NSString *)value y:(CGFloat)y {
    return [self fieldInBox:box label:label value:value y:y x:100 width:380];
}

- (NSTextField *)fieldInBox:(NSBox *)box label:(NSString *)label value:(NSString *)value y:(CGFloat)y x:(CGFloat)x width:(CGFloat)width {
    [box addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, width, 22)];
    field.stringValue = value;
    [box addSubview:field];
    return field;
}

- (NSPopUpButton *)popInBox:(NSBox *)box label:(NSString *)label y:(CGFloat)y {
    [box addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, y - 2, 180, 26) pullsDown:NO];
    [pop addItemsWithTitles:@[
        @"center", @"top-left", @"top-center", @"top-right",
        @"left-center", @"right-center",
        @"bottom-left", @"bottom-center", @"bottom-right",
    ]];
    [box addSubview:pop];
    return pop;
}

- (NSSlider *)sliderInBox:(NSBox *)box label:(NSString *)label y:(CGFloat)y min:(double)min max:(double)max val:(double)val {
    [box addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 300, 22)];
    slider.minValue = min;
    slider.maxValue = max;
    slider.doubleValue = val;
    [box addSubview:slider];
    return slider;
}

- (NSSlider *)sliderOnView:(NSView *)view label:(NSString *)label y:(CGFloat)y min:(double)min max:(double)max val:(double)val {
    [view addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 400, 22)];
    slider.minValue = min;
    slider.maxValue = max;
    slider.doubleValue = val;
    [view addSubview:slider];
    return slider;
}

- (NSPopUpButton *)popOnView:(NSView *)view label:(NSString *)label y:(CGFloat)y {
    [view addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, y - 2, 120, 26) pullsDown:NO];
    [pop addItemWithTitle:@"single"];
    [view addSubview:pop];
    return pop;
}

- (NSTextField *)fieldOnView:(NSView *)view label:(NSString *)label value:(NSString *)value y:(CGFloat)y {
    [view addSubview:[self label:label frame:NSMakeRect(16, y, 80, 22)]];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(100, y, 400, 22)];
    field.stringValue = value;
    [view addSubview:field];
    return field;
}

#pragma mark - Pickers

- (NSTextField *)fieldForPickTag:(NSInteger)tag {
    switch (tag) {
        case 1001: return self.wordInputField;
        case 1002: return self.wordOutputField;
        case 2001: return self.wmInputField;
        case 2002: return self.wmOutputField;
        case 2010: return self.wmImagePathField;
        case 3001: return self.compressInputField;
        case 3002: return self.compressOutputField;
        case 4001: return self.mergeOutputField;
        case 5001: return self.splitInputField;
        case 5002: return self.splitOutputDirField;
        default: return nil;
    }
}

- (void)pickFile:(NSButton *)sender {
    BOOL save = [objc_getAssociatedObject(sender, "save") boolValue];
    BOOL directory = [objc_getAssociatedObject(sender, "directory") boolValue];
    NSTextField *field = [self fieldForPickTag:sender.tag];
    if (!field) {
        field = objc_getAssociatedObject(sender, "field");
    }
    if (directory) {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseDirectories = YES;
        panel.canChooseFiles = NO;
        panel.canCreateDirectories = YES;
        if ([panel runModal] == NSModalResponseOK) {
            field.stringValue = panel.URL.path;
        }
        return;
    }
    if (save) {
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.allowedFileTypes = @[@"pdf"];
        if (field.stringValue.length > 0) {
            panel.directoryURL = [NSURL fileURLWithPath:[field.stringValue stringByDeletingLastPathComponent]];
            panel.nameFieldStringValue = field.stringValue.lastPathComponent;
        }
        if ([panel runModal] == NSModalResponseOK) {
            field.stringValue = panel.URL.path;
        }
        return;
    }
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = NO;
    if (sender.tag == 1001) {
        panel.allowedFileTypes = @[@"doc", @"docx", @"wps", @"rtf", @"odt", @"pdf"];
    } else if (sender.tag == 2010) {
        panel.allowedFileTypes = @[@"png", @"jpg", @"jpeg", @"webp", @"bmp"];
    } else {
        panel.allowedFileTypes = @[@"pdf"];
    }
    if ([panel runModal] == NSModalResponseOK) {
        NSString *path = panel.URL.path;
        field.stringValue = path;
        [self autoFillOutputForPickTag:sender.tag inputPath:path];
    }
}

- (void)autoFillOutputForPickTag:(NSInteger)tag inputPath:(NSString *)path {
    NSString *base = [path stringByDeletingPathExtension];
    if (tag == 1001) {
        self.wordOutputField.stringValue = [base stringByAppendingPathExtension:@"pdf"];
    } else if (tag == 2001) {
        self.wmOutputField.stringValue = [base stringByAppendingString:@"_watermark.pdf"];
    } else if (tag == 3001) {
        self.compressOutputField.stringValue = [base stringByAppendingString:@"_compressed.pdf"];
    } else if (tag == 5001) {
        self.splitOutputDirField.stringValue = [path stringByDeletingLastPathComponent];
    }
}

#pragma mark - Actions

- (void)wmModeChanged:(NSButton *)sender {
    self.wmTextMode = (self.wmTextRadio.state == NSControlStateValueOn);
    self.wmTextBox.hidden = !self.wmTextMode;
    self.wmImageBox.hidden = self.wmTextMode;
}

- (void)mergeAddFiles {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"pdf"];
    panel.allowsMultipleSelection = YES;
    if ([panel runModal] == NSModalResponseOK) {
        for (NSURL *url in panel.URLs) {
            [self.mergeFiles addObject:url.path];
        }
        [self.mergeTableView reloadData];
    }
}

- (void)mergeRemoveSelected {
    NSInteger row = self.mergeTableView.selectedRow;
    if (row >= 0 && row < (NSInteger)self.mergeFiles.count) {
        [self.mergeFiles removeObjectAtIndex:(NSUInteger)row];
        [self.mergeTableView reloadData];
    }
}

- (void)mergeClear {
    [self.mergeFiles removeAllObjects];
    [self.mergeTableView reloadData];
}

- (NSString *)compressLevel {
    if (self.compressLightRadio.state == NSControlStateValueOn) return @"light";
    if (self.compressStrongRadio.state == NSControlStateValueOn) return @"strong";
    return @"medium";
}

- (void)setBusy:(BOOL)busy title:(NSString *)title {
    self.busy = busy;
    self.statusLabel.stringValue = title;
    if (busy) {
        [self.busyIndicator startAnimation:nil];
    } else {
        [self.busyIndicator stopAnimation:nil];
    }
    self.window.title = busy ? [NSString stringWithFormat:@"%@ - 处理中", @"PDFTool"] : @"PDFTool - PDF 工具 (macOS)";
}

- (void)runTask:(NSString *)name work:(void (^)(void (^done)(NSString * _Nullable message, NSString * _Nullable error)))work {
    if (self.busy) return;
    [self setBusy:YES title:[NSString stringWithFormat:@"%@ 处理中…", name]];
    work(^(NSString *message, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error.length > 0) {
                [self setBusy:NO title:[NSString stringWithFormat:@"%@ 失败", name]];
                [self showAlert:@"错误" message:error];
            } else {
                [self setBusy:NO title:[NSString stringWithFormat:@"%@ 完成", name]];
                [self showAlert:@"完成" message:message ?: @""];
            }
        });
    });
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert addButtonWithTitle:@"好"];
    [alert runModal];
}

- (void)runWordConvert {
    NSString *input = self.wordInputField.stringValue;
    NSString *output = self.wordOutputField.stringValue;
    if (input.length == 0 || output.length == 0) {
        [self showAlert:@"提示" message:@"请选择源文件和输出路径"];
        return;
    }
    [self runTask:@"Word 转 PDF" work:^(void (^done)(NSString *, NSString *)) {
        [QYPTEngineClient runCommand:@"word" arguments:@[@"--input", input, @"--output", output] completion:^(NSDictionary *data, NSError *error) {
            if (error) {
                done(nil, error.localizedDescription);
                return;
            }
            NSString *path = data[@"path"] ?: output;
            done([NSString stringWithFormat:@"已生成：\n%@", path], nil);
        }];
    }];
}

- (void)runWatermark {
    NSString *input = self.wmInputField.stringValue;
    NSString *output = self.wmOutputField.stringValue;
    if (input.length == 0 || output.length == 0) {
        [self showAlert:@"提示" message:@"请选择输入和输出 PDF"];
        return;
    }
    double opacity = self.wmOpacitySlider.doubleValue;
    NSString *layout = self.wmLayoutPop.titleOfSelectedItem ?: @"single";
    NSMutableArray<NSString *> *args = [NSMutableArray arrayWithObjects:
                                      @"--input", input, @"--output", output,
                                      @"--opacity", [NSString stringWithFormat:@"%.3f", opacity],
                                      @"--layout", layout, nil];
    NSString *command;
    if (self.wmTextMode) {
        command = @"watermark-text";
        [args addObjectsFromArray:@[
            @"--text", self.wmTextField.stringValue,
            @"--angle", self.wmAngleField.stringValue,
            @"--font-size", self.wmFontField.stringValue,
            @"--position", self.wmTextPositionPop.titleOfSelectedItem ?: @"center",
        ]];
    } else {
        NSString *image = self.wmImagePathField.stringValue;
        if (image.length == 0) {
            [self showAlert:@"提示" message:@"请选择水印图片"];
            return;
        }
        command = @"watermark-image";
        [args addObjectsFromArray:@[
            @"--image", image,
            @"--scale", [NSString stringWithFormat:@"%.3f", self.wmScaleSlider.doubleValue],
            @"--angle", self.wmImgAngleField.stringValue,
            @"--position", self.wmImagePositionPop.titleOfSelectedItem ?: @"center",
        ]];
    }
    [self runTask:@"添加水印" work:^(void (^done)(NSString *, NSString *)) {
        [QYPTEngineClient runCommand:command arguments:args completion:^(NSDictionary * _Nullable data, NSError *error) {
            (void)data;
            if (error) {
                done(nil, error.localizedDescription);
                return;
            }
            done([NSString stringWithFormat:@"已生成：\n%@", output], nil);
        }];
    }];
}

- (void)runCompress {
    NSString *input = self.compressInputField.stringValue;
    NSString *output = self.compressOutputField.stringValue;
    if (input.length == 0 || output.length == 0) {
        [self showAlert:@"提示" message:@"请选择输入和输出 PDF"];
        return;
    }
    NSString *level = [self compressLevel];
    [self runTask:@"PDF 压缩" work:^(void (^done)(NSString *, NSString *)) {
        [QYPTEngineClient runCommand:@"compress" arguments:@[
            @"--input", input, @"--output", output, @"--level", level,
        ] completion:^(NSDictionary *data, NSError *error) {
            if (error) {
                done(nil, error.localizedDescription);
                return;
            }
            NSInteger before = [data[@"before"] integerValue];
            NSInteger after = [data[@"after"] integerValue];
            double ratio = [data[@"ratio"] doubleValue];
            NSString *method = data[@"method_label"] ?: @"";
            NSString *msg = [NSString stringWithFormat:
                             @"方式：%@\n原始：%@\n压缩后：%@\n节省：%@（%.1f%%）\n\n%@",
                             method, [self formatBytes:before], [self formatBytes:after],
                             [self formatBytes:MAX(0, before - after)], ratio, output];
            done(msg, nil);
        }];
    }];
}

- (void)runMerge {
    if (self.mergeFiles.count < 2) {
        [self showAlert:@"提示" message:@"请至少添加 2 个 PDF"];
        return;
    }
    NSString *output = self.mergeOutputField.stringValue;
    if (output.length == 0) {
        [self showAlert:@"提示" message:@"请选择输出路径"];
        return;
    }
    NSMutableArray<NSString *> *args = [NSMutableArray arrayWithObjects:@"--output", output, @"--inputs", nil];
    [args addObjectsFromArray:self.mergeFiles];
    [self runTask:@"合并 PDF" work:^(void (^done)(NSString *, NSString *)) {
        [QYPTEngineClient runCommand:@"merge" arguments:args completion:^(NSDictionary * _Nullable data, NSError *error) {
            (void)data;
            if (error) {
                done(nil, error.localizedDescription);
                return;
            }
            done([NSString stringWithFormat:@"已生成：\n%@", output], nil);
        }];
    }];
}

- (void)runSplit {
    NSString *input = self.splitInputField.stringValue;
    NSString *outDir = self.splitOutputDirField.stringValue;
    if (input.length == 0 || outDir.length == 0) {
        [self showAlert:@"提示" message:@"请选择 PDF 和输出目录"];
        return;
    }
    BOOL each = (self.splitEachRadio.state == NSControlStateValueOn);
    [self runTask:@"拆分 PDF" work:^(void (^done)(NSString *, NSString *)) {
        if (each) {
            [QYPTEngineClient runCommand:@"split-each" arguments:@[
                @"--input", input, @"--output-dir", outDir,
            ] completion:^(NSDictionary *data, NSError *error) {
                if (error) {
                    done(nil, error.localizedDescription);
                    return;
                }
                NSInteger count = [data[@"count"] integerValue];
                done([NSString stringWithFormat:@"共生成 %ld 个文件\n目录：%@", (long)count, outDir], nil);
            }];
        } else {
            [QYPTEngineClient runCommand:@"split-range" arguments:@[
                @"--input", input, @"--output-dir", outDir,
                @"--ranges", self.splitRangeField.stringValue,
            ] completion:^(NSDictionary *data, NSError *error) {
                if (error) {
                    done(nil, error.localizedDescription);
                    return;
                }
                NSInteger count = [data[@"count"] integerValue];
                done([NSString stringWithFormat:@"共生成 %ld 个文件\n目录：%@", (long)count, outDir], nil);
            }];
        }
    }];
}

- (NSString *)formatBytes:(NSInteger)n {
    if (n >= 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)n / 1024.0 / 1024.0];
    }
    if (n >= 1024) {
        return [NSString stringWithFormat:@"%.1f KB", (double)n / 1024.0];
    }
    return [NSString stringWithFormat:@"%ld B", (long)n];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.mergeFiles.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *path = self.mergeFiles[(NSUInteger)row];
    return [NSString stringWithFormat:@"%ld. %@", (long)(row + 1), path.lastPathComponent];
}

@end
