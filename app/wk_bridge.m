#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface BridgeRequest : NSObject
@property (nonatomic, assign) int reqId;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *payload;
@end

@implementation BridgeRequest
@end

@interface AppBridgeDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSMutableArray<BridgeRequest *> *requestQueue;
@property (nonatomic, assign) BOOL isRunning;
@end

@implementation AppBridgeDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestQueue = [[NSMutableArray alloc] init];
        _isRunning = YES;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSString class]]) return;
    
    NSData *data = [((NSString *)message.body) dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![dict isKindOfClass:[NSDictionary class]]) return;
    
    NSNumber *reqId = dict[@"id"];
    NSString *method = dict[@"method"];
    id params = dict[@"params"] ?: @{};
    
    NSData *paramData = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
    NSString *paramStr = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding] ?: @"{}";
    
    BridgeRequest *req = [[BridgeRequest alloc] init];
    req.reqId = [reqId intValue];
    req.method = method ?: @"";
    req.payload = paramStr;
    
    @synchronized (self.requestQueue) {
        [self.requestQueue addObject:req];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    _isRunning = NO;
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    _isRunning = NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    _isRunning = NO;
    return NSTerminateNow;
}

@end

static AppBridgeDelegate *g_delegate = nil;

static void setup_app_menu(NSString *appName) {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    
    // App Menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"关于 %@", appName] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"隐藏 %@", appName] action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"隐藏其他" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    [appMenu addItem:hideOthers];
    [appMenu addItemWithTitle:@"全部显示" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"退出 %@", appName] action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];
    [mainMenu addItem:appMenuItem];
    
    // Edit Menu
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    [editMenu addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"重做" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenuItem setSubmenu:editMenu];
    [mainMenu addItem:editMenuItem];

    // Window Menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"窗口"];
    [windowMenu addItemWithTitle:@"最小化" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"缩放" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"关闭" action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenuItem setSubmenu:windowMenu];
    [mainMenu addItem:windowMenuItem];
    
    [NSApp setMainMenu:mainMenu];
}

static void setup_app_icon(NSString *iconPath) {
    if (iconPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (image) {
            CFBundleRef mainBundle = CFBundleGetMainBundle();
            CFDictionaryRef infoDict = mainBundle ? CFBundleGetInfoDictionary(mainBundle) : NULL;
            int isAppBundle = (infoDict != NULL && CFDictionaryGetValue(infoDict, CFSTR("CFBundlePackageType")) != NULL);
            if (!isAppBundle && NSApp != nil) {
                NSImageView *dockView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, NSApp.dockTile.size.width, NSApp.dockTile.size.height)];
                dockView.image = image;
                dockView.imageScaling = NSImageScaleAxesIndependently;
                NSApp.dockTile.contentView = dockView;
                [NSApp.dockTile display];
            }
        }
    }
}

int wk_bridge_init(const char *title, int width, int height, const char *frontend_dir, const char *icon_path) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    NSString *nsTitle = [NSString stringWithUTF8String:title ? title : "PDF 水印"];
    setup_app_menu(nsTitle);
    
    if (icon_path && icon_path[0] != '\0') {
        setup_app_icon([NSString stringWithUTF8String:icon_path]);
    }
    
    g_delegate = [[AppBridgeDelegate alloc] init];
    [NSApp setDelegate:g_delegate];
    
    NSRect frame = NSMakeRect(0, 0, width, height);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:nsTitle];
    [window center];
    [window setDelegate:g_delegate];
    g_delegate.window = window;
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
    
    NSString *bridgeScript = @"(function(){\n"
    "  if (window.__MoonBitBridge) return;\n"
    "  window.__MoonBitBridge = {\n"
    "    reqId: 1,\n"
    "    callbacks: {},\n"
    "    resolve: function(id, res) {\n"
    "      var cb = this.callbacks[id];\n"
    "      if (cb) { delete this.callbacks[id]; cb.resolve(res); }\n"
    "    },\n"
    "    reject: function(id, err) {\n"
    "      var cb = this.callbacks[id];\n"
    "      if (cb) { delete this.callbacks[id]; cb.reject(new Error(err)); }\n"
    "    },\n"
    "    invoke: function(method, params) {\n"
    "      var self = this;\n"
    "      return new Promise(function(resolve, reject) {\n"
    "        var id = self.reqId++;\n"
    "        self.callbacks[id] = { resolve: resolve, reject: reject };\n"
    "        window.webkit.messageHandlers.moonbit.postMessage(JSON.stringify({\n"
    "          id: id,\n"
    "          method: method,\n"
    "          params: params || {}\n"
    "        }));\n"
    "      });\n"
    "    }\n"
    "  };\n"
    "  window.__MoonBit__ = {\n"
    "    app: {\n"
    "      choosePdf: function() { return window.__MoonBitBridge.invoke('choosePdf', {}); },\n"
    "      chooseImage: function() { return window.__MoonBitBridge.invoke('chooseImage', {}); },\n"
    "      openPdfPath: function(p) { return window.__MoonBitBridge.invoke('openPdfPath', p); },\n"
    "      dropPdfData: function(p) { return window.__MoonBitBridge.invoke('dropPdfData', p); },\n"
    "      openImagePath: function(p) { return window.__MoonBitBridge.invoke('openImagePath', p); },\n"
    "      dropImageData: function(p) { return window.__MoonBitBridge.invoke('dropImageData', p); },\n"
    "      applyWatermarkNative: function(p) { return window.__MoonBitBridge.invoke('applyWatermarkNative', p); },\n"
    "      revealPdf: function() { return window.__MoonBitBridge.invoke('revealPdf', {}); }\n"
    "    }\n"
    "  };\n"
    "})();\n";
    
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:bridgeScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:YES];
    [config.userContentController addUserScript:userScript];
    [config.userContentController addScriptMessageHandler:g_delegate name:@"moonbit"];
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    g_delegate.webView = webView;
    [window setContentView:webView];
    
    NSString *dirStr = [NSString stringWithUTF8String:frontend_dir];
    NSString *indexStr = [dirStr stringByAppendingPathComponent:@"index.html"];
    NSURL *indexURL = [NSURL fileURLWithPath:indexStr];
    NSURL *dirURL = [NSURL fileURLWithPath:dirStr];
    
    [webView loadFileURL:indexURL allowingReadAccessToURL:dirURL];
    
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    return 1;
}

int wk_bridge_pump_events(void) {
    if (!g_delegate || !g_delegate.isRunning) return 0;
    
    @autoreleasepool {
        for (;;) {
            NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                untilDate:[NSDate dateWithTimeIntervalSinceNow:0.015]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event == nil) break;
            [NSApp sendEvent:event];
        }
    }
    
    return g_delegate.isRunning ? 1 : 0;
}

int wk_bridge_poll_request(int *out_id, char *out_method, int method_max, char *out_payload, int payload_max) {
    if (!g_delegate) return 0;
    
    BridgeRequest *req = nil;
    @synchronized (g_delegate.requestQueue) {
        if (g_delegate.requestQueue.count > 0) {
            req = g_delegate.requestQueue[0];
            [g_delegate.requestQueue removeObjectAtIndex:0];
        }
    }
    
    if (!req) return 0;
    
    if (out_id) *out_id = req.reqId;
    if (out_method && method_max > 0) {
        const char *m = [req.method UTF8String];
        strncpy(out_method, m ? m : "", method_max - 1);
        out_method[method_max - 1] = '\0';
    }
    if (out_payload && payload_max > 0) {
        const char *p = [req.payload UTF8String];
        strncpy(out_payload, p ? p : "{}", payload_max - 1);
        out_payload[payload_max - 1] = '\0';
    }
    
    return 1;
}

void wk_bridge_reply(int req_id, const char *result_json, int is_error) {
    if (!g_delegate || !g_delegate.webView) return;
    
    NSString *jsonStr = [NSString stringWithUTF8String:result_json ? result_json : "null"];
    NSString *script;
    if (is_error) {
        NSData *escapedData = [NSJSONSerialization dataWithJSONObject:jsonStr options:0 error:nil];
        NSString *escapedStr = [[NSString alloc] initWithData:escapedData encoding:NSUTF8StringEncoding] ?: @"\"Error\"";
        script = [NSString stringWithFormat:@"window.__MoonBitBridge.reject(%d, %@);", req_id, escapedStr];
    } else {
        script = [NSString stringWithFormat:@"window.__MoonBitBridge.resolve(%d, %@);", req_id, jsonStr];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_delegate.webView evaluateJavaScript:script completionHandler:nil];
    });
}

void wk_bridge_eval(const char *script_utf8) {
    if (!g_delegate || !g_delegate.webView || !script_utf8) return;
    NSString *script = [NSString stringWithUTF8String:script_utf8];
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_delegate.webView evaluateJavaScript:script completionHandler:nil];
    });
}

int wk_bridge_choose_file(int is_image, char *out_path, int path_max) {
    __block int result = 0;
    void (^block)(void) = ^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseFiles = YES;
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = NO;
        
        if (is_image) {
            panel.title = @"选择图片或印章";
            panel.allowedContentTypes = @[UTTypePNG, UTTypeJPEG];
        } else {
            panel.title = @"选择要添加水印的 PDF 文件";
            panel.allowedContentTypes = @[UTTypePDF];
        }
        
        if ([panel runModal] == NSModalResponseOK && panel.URL.path) {
            const char *p = [panel.URL.path UTF8String];
            if (p && out_path && path_max > 0) {
                strncpy(out_path, p, path_max - 1);
                out_path[path_max - 1] = '\0';
                result = 1;
            }
        }
    };
    
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
    return result;
}

int wk_bridge_save_file(const char *title, const char *default_path, char *out_path, int path_max) {
    __block int result = 0;
    NSString *nsTitle = [NSString stringWithUTF8String:title ? title : "保存水印 PDF"];
    NSString *nsDefault = [NSString stringWithUTF8String:default_path ? default_path : ""];
    
    void (^block)(void) = ^{
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.title = nsTitle;
        panel.allowedContentTypes = @[UTTypePDF];
        
        if (nsDefault.length > 0) {
            panel.directoryURL = [NSURL fileURLWithPath:[nsDefault stringByDeletingLastPathComponent]];
            panel.nameFieldStringValue = [nsDefault lastPathComponent];
        }
        
        if ([panel runModal] == NSModalResponseOK && panel.URL.path) {
            const char *p = [panel.URL.path UTF8String];
            if (p && out_path && path_max > 0) {
                strncpy(out_path, p, path_max - 1);
                out_path[path_max - 1] = '\0';
                result = 1;
            }
        }
    };
    
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
    return result;
}

void wk_bridge_reveal_file(const char *path) {
    if (!path || path[0] == '\0') return;
    NSString *nsPath = [NSString stringWithUTF8String:path];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSWorkspace sharedWorkspace] selectFile:nsPath inFileViewerRootedAtPath:@""];
    });
}
