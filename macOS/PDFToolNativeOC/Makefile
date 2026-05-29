APP_NAME = PDFToolNative
SDK = $(shell xcrun --show-sdk-path 2>/dev/null)
CC = clang
CFLAGS = -fobjc-arc -Wall -Wextra -mmacosx-version-min=11.0 -isysroot $(SDK)
LDFLAGS = -framework Cocoa -framework Security -framework AVFoundation

SRCS = main.m \
	QYPTAppDelegate.m \
	QYPTAuthHelper.m \
	QYPTEngineClient.m \
	QYPTFFmpegAudio.m \
	QYPTHubWindowController.m \
	QYPTMainWindowController.m \
	QYPTAudioEditWindowController.m

OBJS = $(SRCS:.m=.o)

.PHONY: all clean

all: $(APP_NAME)

$(APP_NAME): $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@

%.o: %.m
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(APP_NAME)
