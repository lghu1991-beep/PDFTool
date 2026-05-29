#import <Cocoa/Cocoa.h>
#import "QYPTAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        QYPTAppDelegate *delegate = [[QYPTAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
