#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface DXNotificationElement : NSObject {
    id _clientStorage, _scene, _layoutHost, _elementHost;
    id _clientIdentifier, _elementIdentifier;
    UIView *_leadingView, *_trailingView, *_minimalView, *_detachedMinimalView;
    NSInteger _layoutMode, _preferredLayoutMode;
    BOOL _suppressed;
}
@end

@implementation DXNotificationElement
- (id)element { return self; }
- (id)viewProvider { return self; }
- (id)clientIdentifier { return _clientIdentifier; }
- (void)setClientIdentifier:(id)v { _clientIdentifier=v; }
- (id)elementIdentifier { return _elementIdentifier; }
- (void)setElementIdentifier:(id)v { _elementIdentifier=v; }
- (UIView *)leadingView { return _leadingView; }
- (void)setLeadingView:(UIView *)v { _leadingView=v; }
- (UIView *)trailingView { return _trailingView; }
- (void)setTrailingView:(UIView *)v { _trailingView=v; }
- (UIView *)minimalView { return _minimalView ?: _leadingView; }
- (void)setMinimalView:(UIView *)v { _minimalView=v; }
- (UIView *)detachedMinimalView { return _detachedMinimalView ?: self.minimalView; }
- (void)setDetachedMinimalView:(UIView *)v { _detachedMinimalView=v; }
- (NSInteger)preferredLayoutMode { return _preferredLayoutMode ?: 2; }
- (void)setPreferredLayoutMode:(NSInteger)v { _preferredLayoutMode=v; }
- (NSInteger)minimumSupportedLayoutMode { return -1; }
- (NSInteger)maximumSupportedLayoutMode { return 2; }
- (NSUInteger)layoutAxis { return -1; }
- (NSInteger)layoutMode { return _layoutMode; }
- (void)setLayoutMode:(NSInteger)v { _layoutMode=v; }
- (void)setLayoutMode:(NSInteger)mode reason:(NSInteger)reason { _layoutMode=mode; }
- (UIEdgeInsets)preferredEdgeOutsetsForLayoutMode:(NSInteger)mode suggestedOutsets:(UIEdgeInsets)suggested maximumOutsets:(UIEdgeInsets)maximum { return suggested; }
- (BOOL)isMinimalPresentationPossible { return YES; }
- (void)updateLayout { [_leadingView setNeedsLayout]; [_minimalView setNeedsLayout]; [_trailingView setNeedsLayout]; }
- (void)layoutHostContainerViewDidLayoutSubviews:(UIView *)view {}
- (id)initWithStatusBarStyleOverrides:(NSInteger)v { return [super init]; }
- (NSInteger)statusBarStyleOverrides { return 0; }
- (void)setStatusBarStyleOverrides:(NSInteger)v {}
- (BOOL)acceptsFullScreenTransitionFromSceneWithIdentifier:(id)scene ofBundleId:(id)bundle { return NO; }
- (BOOL)shouldSuppressElementWhilePresentingAppWithBundleId:(id)bundle { return NO; }
- (BOOL)shouldSuppressElementWhileOnCoversheet { return NO; }
- (BOOL)shouldIgnoreSystemChromeSuppression { return NO; }
- (BOOL)hasActivityBehavior { return NO; }
- (void)handleElementViewEvent:(NSInteger)a :(NSInteger)b {}
- (id)clientStorage { return _clientStorage; }
- (void)setClientStorage:(id)v { _clientStorage=v; }
- (id)scene { return _scene; }
- (void)setScene:(id)v { _scene=v; }
- (id)layoutHost { return _layoutHost; }
- (void)setLayoutHost:(id)v { _layoutHost=v; }
- (id)elementHost { return _elementHost; }
- (void)setElementHost:(id)v { _elementHost=v; }
- (BOOL)suppressed { return _suppressed; }
- (void)setSuppressed:(BOOL)v { _suppressed=v; }
@end

static void DXRegisterProtocols(void) {
    Class cls=[DXNotificationElement class];
    const char *names[]={
        "SAElement","SAElementIdentifying","SAElementViewProviding",
        "SAUIElementViewProviding","SAUILayoutSpecifying",
        "SBSystemApertureStatusBarStyleOverridesRepresenting",
        "SBSystemApertureLayoutCustomizing","SBSystemApertureSuppressible"
    };
    NSUInteger found=0;
    for (NSUInteger i=0;i<sizeof(names)/sizeof(names[0]);i++) {
        Protocol *p=objc_getProtocol(names[i]);
        if (p) {
            found++;
            if (!class_conformsToProtocol(cls,p)) class_addProtocol(cls,p);
            NSLog(@"[DXCore] protocol found: %s", names[i]);
        } else {
            NSLog(@"[DXCore] protocol MISSING: %s", names[i]);
        }
    }
    NSLog(@"[DXCore] protocols: %lu/%lu found", (unsigned long)found, (unsigned long)(sizeof(names)/sizeof(names[0])));
}

static UIView *DXMakeView(NSString *title, NSString *body) {
    UIView *v=[UIView new];
    UILabel *l=[UILabel new];
    l.text=body.length ? [NSString stringWithFormat:@"%@  %@",title ?: @"通知",body] : (title ?: @"通知");
    l.textColor=UIColor.whiteColor;
    l.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.numberOfLines=1;
    [v addSubview:l];
    l.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[
        [l.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [l.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        [l.topAnchor constraintEqualToAnchor:v.topAnchor],
        [l.bottomAnchor constraintEqualToAnchor:v.bottomAnchor]
    ]];
    return v;
}

static void DXShowNotification(id request) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c=NSClassFromString(@"SBSystemApertureViewController");
        if (!c) { NSLog(@"[DXCore] SBSystemApertureViewController class NOT FOUND"); return; }
        SEL sharedSel=sel_registerName("sharedInstance");
        if (![c respondsToSelector:sharedSel]) { NSLog(@"[DXCore] sharedInstance NOT FOUND"); return; }
        id controller=((id(*)(id,SEL))objc_msgSend)(c,sharedSel);
        if (!controller) { NSLog(@"[DXCore] sharedInstance returned nil"); return; }
        NSLog(@"[DXCore] got controller: %@", controller);

        id content=nil;
        SEL contentSel=sel_registerName("content");
        if ([request respondsToSelector:contentSel])
            content=((id(*)(id,SEL))objc_msgSend)(request,contentSel);

        NSString *title=nil,*body=nil;
        if (content) {
            SEL ts=sel_registerName("title"), bs=sel_registerName("body");
            if ([content respondsToSelector:ts]) title=((id(*)(id,SEL))objc_msgSend)(content,ts);
            if ([content respondsToSelector:bs]) body=((id(*)(id,SEL))objc_msgSend)(content,bs);
        }

        DXNotificationElement *element=[DXNotificationElement new];
        [element setClientIdentifier:@"com.apple.springboard"];
        [element setElementIdentifier:[[NSUUID UUID] UUIDString]];
        [element setLayoutMode:2];
        [element setPreferredLayoutMode:2];

        UIView *expanded=DXMakeView(title,body);
        UIView *minimal=DXMakeView(@"",@"●");
        [element setLeadingView:expanded];
        [element setMinimalView:minimal];
        [element setDetachedMinimalView:minimal];

        SEL registerSel=sel_registerName("registerElement:");
        if ([controller respondsToSelector:registerSel]) {
            id storage=((id(*)(id,SEL,id))objc_msgSend)(controller,registerSel,element);
            if (storage) [element setClientStorage:storage];
            NSLog(@"[DXCore] registerElement called, storage=%@", storage ? @"yes" : @"nil");
        } else {
            NSLog(@"[DXCore] registerElement: NOT FOUND on controller");
        }
    });
}

%hook NCNotificationDispatcher
- (void)postNotificationWithRequest:(id)request {
    %orig;
    DXShowNotification(request);
}
%end

%ctor {
    if (NSClassFromString(@"SBSystemApertureViewController")) DXRegisterProtocols();
}
