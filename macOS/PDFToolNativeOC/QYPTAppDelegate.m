#import "QYPTAppDelegate.h"
#import "QYPTAuthHelper.h"
#import "QYPTHubWindowController.h"
#import "QYPTMainWindowController.h"
#import "QYPTAudioEditWindowController.h"

@interface QYPTAppDelegate ()
@property (nonatomic, strong) QYPTHubWindowController *hubController;
@property (nonatomic, strong) QYPTMainWindowController *pdfController;
@property (nonatomic, strong) QYPTAudioEditWindowController *audioController;
@property (nonatomic, strong) NSWindow *loginWindow;
@property (nonatomic, strong) NSSecureTextField *passwordField;
@end

@implementation QYPTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self showLoginWindow];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)showLoginWindow {
    self.loginWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 380, 160)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self.loginWindow.title = @"工具集 - 身份验证";
    self.loginWindow.releasedWhenClosed = NO;

    NSView *content = self.loginWindow.contentView;
    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 110, 340, 28)];
    title.stringValue = @"请输入使用密码";
    title.editable = NO;
    title.bezeled = NO;
    title.drawsBackground = NO;
    title.font = [NSFont boldSystemFontOfSize:15];
    [content addSubview:title];

    self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(20, 72, 340, 24)];
    [content addSubview:self.passwordField];

    NSButton *cancel = [[NSButton alloc] initWithFrame:NSMakeRect(200, 20, 72, 32)];
    cancel.title = @"取消";
    cancel.bezelStyle = NSBezelStyleRounded;
    cancel.target = self;
    cancel.action = @selector(loginCancel:);
    [content addSubview:cancel];

    NSButton *ok = [[NSButton alloc] initWithFrame:NSMakeRect(280, 20, 80, 32)];
    ok.title = @"进入";
    ok.bezelStyle = NSBezelStyleRounded;
    ok.keyEquivalent = @"\r";
    ok.target = self;
    ok.action = @selector(loginConfirm:);
    [content addSubview:ok];

    [self.loginWindow center];
    [self.loginWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)loginConfirm:(id)sender {
    if ([QYPTAuthHelper verifyPassword:self.passwordField.stringValue]) {
        [self.loginWindow orderOut:nil];
        self.loginWindow = nil;
        [self showHubWindow];
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"错误";
    alert.informativeText = @"密码错误，请重试。";
    [alert addButtonWithTitle:@"好"];
    [alert runModal];
    [self.passwordField selectText:nil];
}

- (void)loginCancel:(id)sender {
    [NSApp terminate:nil];
}

- (void)showHubWindow {
    if (!self.hubController) {
        self.hubController = [[QYPTHubWindowController alloc] init];
        __weak typeof(self) weakSelf = self;
        [self.hubController setOpenPDFHandler:^{
            [weakSelf openPDFTool];
        }];
        [self.hubController setOpenAudioHandler:^{
            [weakSelf openAudioTool];
        }];
    }
    [self.hubController showWindow:nil];
    [self.hubController.window center];
    [self.hubController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openPDFTool {
    if (!self.pdfController) {
        self.pdfController = [[QYPTMainWindowController alloc] init];
    }
    [self.pdfController showWindow:nil];
    [self.pdfController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openAudioTool {
    if (!self.audioController) {
        self.audioController = [[QYPTAudioEditWindowController alloc] init];
    }
    [self.audioController showWindow:nil];
    [self.audioController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
