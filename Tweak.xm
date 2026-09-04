#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Settings

static NSString * const DINDefaultsSuite = @"com.1205417239.dynamiclslandnotify";
static NSString * const DINEnabledKey = @"enabled";

static BOOL DINEnabled(void) {
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:DINDefaultsSuite];

    NSNumber *value = [defaults objectForKey:DINEnabledKey];

    if (!value) {
        return YES;
    }

    return [value boolValue];
}

#pragma mark - Notification Item

@interface DINNotificationItem : NSObject

@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *body;
@property(nonatomic,copy) NSString *bundleID;
@property(nonatomic,copy) NSString *requestID;

@end

@implementation DINNotificationItem
@end

#pragma mark - Dynamic Island Controller

@interface DINIslandController : NSObject

@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) UIView *islandView;

@property(nonatomic,strong) UIImageView *iconView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *bodyLabel;

@property(nonatomic,strong) NSMutableArray *queue;

@property(nonatomic,assign) BOOL showing;
@property(nonatomic,assign) BOOL expanded;

@property(nonatomic,copy) NSString *currentBundleID;

@end

@implementation DINIslandController

+ (instancetype)sharedController {
    static DINIslandController *controller;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        controller = [[DINIslandController alloc] init];
    });

    return controller;
}

#pragma mark - Window

- (void)createWindowIfNeeded {

    if (self.window) {
        return;
    }

    UIScreen *screen = [UIScreen mainScreen];

    self.window =
        [[UIWindow alloc] initWithFrame:screen.bounds];

    self.window.backgroundColor = UIColor.clearColor;

    /*
     * This is only the visual overlay.
     * It does not replace Notification Center.
     */
    self.window.windowLevel = UIWindowLevelAlert + 1;

    UIViewController *controller =
        [[UIViewController alloc] init];

    controller.view.backgroundColor =
        UIColor.clearColor;

    self.window.rootViewController = controller;

    self.window.hidden = NO;

    self.queue = [NSMutableArray array];

    [self createIslandViewInController:controller];
}

#pragma mark - Island UI

- (void)createIslandViewInController:(UIViewController *)controller {

    CGFloat screenWidth =
        UIScreen.mainScreen.bounds.size.width;

    CGFloat width = 126.0;
    CGFloat height = 37.0;

    self.islandView =
        [[UIView alloc]
            initWithFrame:CGRectMake(
                (screenWidth - width) / 2.0,
                11.0,
                width,
                height)];

    self.islandView.backgroundColor =
        UIColor.blackColor;

    self.islandView.layer.cornerRadius =
        height / 2.0;

    self.islandView.clipsToBounds = YES;

    self.islandView.userInteractionEnabled = YES;

    [controller.view addSubview:self.islandView];

    /*
     * App icon
     */
    self.iconView =
        [[UIImageView alloc]
            initWithFrame:CGRectMake(
                8.0,
                7.0,
                23.0,
                23.0)];

    self.iconView.layer.cornerRadius = 6.0;
    self.iconView.clipsToBounds = YES;

    [self.islandView addSubview:self.iconView];

    /*
     * Title
     */
    self.titleLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                38.0,
                4.0,
                width - 46.0,
                15.0)];

    self.titleLabel.textColor =
        UIColor.whiteColor;

    self.titleLabel.font =
        [UIFont boldSystemFontOfSize:11.5];

    self.titleLabel.numberOfLines = 1;

    self.titleLabel.lineBreakMode =
        NSLineBreakByTruncatingTail;

    [self.islandView addSubview:self.titleLabel];

    /*
     * Body
     */
    self.bodyLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                38.0,
                19.0,
                width - 46.0,
                13.0)];

    self.bodyLabel.textColor =
        [UIColor colorWithWhite:0.82 alpha:1.0];

    self.bodyLabel.font =
        [UIFont systemFontOfSize:9.5];

    self.bodyLabel.numberOfLines = 1;

    self.bodyLabel.lineBreakMode =
        NSLineBreakByTruncatingTail;

    [self.islandView addSubview:self.bodyLabel];

    /*
     * Tap
     */
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(handleTap:)];

    [self.islandView addGestureRecognizer:tap];

    /*
     * Long press
     */
    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(handleLongPress:)];

    longPress.minimumPressDuration = 0.45;

    [self.islandView addGestureRecognizer:longPress];

    /*
     * Swipe / pan
     */
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(handlePan:)];

    [self.islandView addGestureRecognizer:pan];
}

#pragma mark - Queue

- (void)enqueueNotification:(DINNotificationItem *)item {

    if (!DINEnabled()) {
        return;
    }

    if (!item) {
        return;
    }

    /*
     * Prevent the same request from being queued repeatedly.
     */
    for (DINNotificationItem *oldItem in self.queue) {

        if (oldItem.requestID.length &&
            item.requestID.length &&
            [oldItem.requestID
                isEqualToString:item.requestID]) {

            return;
        }
    }

    if (self.showing) {

        [self.queue addObject:item];

        /*
         * Avoid unlimited queue growth.
         */
        if (self.queue.count > 20) {
            [self.queue removeObjectAtIndex:0];
        }

        return;
    }

    [self showNotification:item];
}

#pragma mark - Show

- (void)showNotification:(DINNotificationItem *)item {

    if (!DINEnabled()) {
        return;
    }

    [self createWindowIfNeeded];

    self.currentBundleID = item.bundleID;

    self.titleLabel.text =
        item.title.length ? item.title : @"通知";

    self.bodyLabel.text =
        item.body.length ? item.body : @"";

    self.iconView.image =
        [self applicationIconForBundleID:item.bundleID];

    self.expanded = NO;
    self.showing = YES;

    UIScreen *screen =
        [UIScreen mainScreen];

    CGFloat width = 126.0;
    CGFloat height = 37.0;

    self.islandView.frame =
        CGRectMake(
            (screen.bounds.size.width - width) / 2.0,
            11.0,
            width,
            height);

    self.islandView.layer.cornerRadius =
        height / 2.0;

    self.iconView.frame =
        CGRectMake(8.0, 7.0, 23.0, 23.0);

    self.titleLabel.frame =
        CGRectMake(38.0, 4.0, width - 46.0, 15.0);

    self.bodyLabel.frame =
        CGRectMake(38.0, 19.0, width - 46.0, 13.0);

    self.bodyLabel.numberOfLines = 1;
    self.bodyLabel.font =
        [UIFont systemFontOfSize:9.5];

    self.islandView.alpha = 0.0;

    self.islandView.transform =
        CGAffineTransformMakeScale(0.70, 0.70);

    /*
     * Spring animation.
     */
    [UIView animateWithDuration:0.32
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.9
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        self.islandView.alpha = 1.0;

        self.islandView.transform =
            CGAffineTransformIdentity;

    } completion:nil];

    /*
     * Auto collapse after a few seconds.
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(3.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{

            if (self.showing &&
                !self.expanded) {

                [self dismissCurrentNotification];
            }
        });
}

#pragma mark - Expand

- (void)expandIsland {

    if (!self.showing ||
        self.expanded) {

        return;
    }

    self.expanded = YES;

    UIScreen *screen =
        [UIScreen mainScreen];

    CGFloat width =
        MIN(screen.bounds.size.width - 32.0, 390.0);

    CGFloat height = 118.0;

    [UIView animateWithDuration:0.32
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        self.islandView.frame =
            CGRectMake(
                (screen.bounds.size.width - width) / 2.0,
                8.0,
                width,
                height);

        self.islandView.layer.cornerRadius = 28.0;

        self.iconView.frame =
            CGRectMake(16.0, 16.0, 38.0, 38.0);

        self.titleLabel.frame =
            CGRectMake(
                64.0,
                13.0,
                width - 82.0,
                20.0);

        self.bodyLabel.frame =
            CGRectMake(
                64.0,
                38.0,
                width - 82.0,
                62.0);

        self.bodyLabel.numberOfLines = 3;

        self.bodyLabel.font =
            [UIFont systemFontOfSize:14.0];

    } completion:nil];
}

#pragma mark - Dismiss

- (void)dismissCurrentNotification {

    if (!self.showing) {
        return;
    }

    self.showing = NO;

    [UIView animateWithDuration:0.20
                     animations:^{

        self.islandView.alpha = 0.0;

        self.islandView.transform =
            CGAffineTransformMakeScale(
                0.82,
                0.82);

    } completion:^(BOOL finished) {

        self.islandView.transform =
            CGAffineTransformIdentity;

        self.islandView.alpha = 1.0;

        self.expanded = NO;

        /*
         * FIFO queue.
         */
        if (self.queue.count > 0) {

            DINNotificationItem *next =
                self.queue.firstObject;

            [self.queue removeObjectAtIndex:0];

            [self showNotification:next];
        }
    }];
}

#pragma mark - Gestures

- (void)handleTap:(UITapGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateEnded) {

        return;
    }

    /*
     * We intentionally don't call an unverified
     * private application-launch selector here.
     *
     * The notification is dismissed safely.
     */
    [self dismissCurrentNotification];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {

    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        [self expandIsland];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateEnded) {

        return;
    }

    CGPoint velocity =
        [gesture velocityInView:self.islandView];

    /*
     * Swipe left to close.
     */
    if (velocity.x < -250.0) {

        [self dismissCurrentNotification];
    }
}

#pragma mark - App Icon

- (UIImage *)applicationIconForBundleID:(NSString *)bundleID {

    if (!bundleID.length) {
        return nil;
    }

    /*
     * iOS private LaunchServices lookup.
     */
    Class workspaceClass =
        NSClassFromString(@"LSApplicationWorkspace");

    if (!workspaceClass) {
        return nil;
    }

    id workspace =
        [workspaceClass
            performSelector:@selector(defaultWorkspace)];

    if (!workspace) {
        return nil;
    }

    id application = nil;

    @try {

        application =
            [workspace
                performSelector:
                    @selector(applicationForBundleIdentifier:)
                withObject:bundleID];

    } @catch (__unused id exception) {

        application = nil;
    }

    if (!application) {
        return nil;
    }

    NSString *iconPath = nil;

    @try {

        iconPath =
            [application valueForKey:@"_iconPath"];

    } @catch (__unused id exception) {

        iconPath = nil;
    }

    if (!iconPath.length) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:iconPath];
}

@end

#pragma mark - Helpers

static NSString *DINGetString(id object,
                               NSArray *keys) {

    if (!object) {
        return @"";
    }

    for (NSString *key in keys) {

        @try {

            id value =
                [object valueForKey:key];

            if ([value isKindOfClass:NSString.class] &&
                [value length] > 0) {

                return value;
            }

        } @catch (__unused id exception) {
        }
    }

    return @"";
}

static DINNotificationItem *
DINCreateItemFromRequest(id request) {

    if (!request) {
        return nil;
    }

    DINNotificationItem *item =
        [[DINNotificationItem alloc] init];

    item.requestID =
        DINGetString(
            request,
            @[
                @"requestIdentifier",
                @"identifier",
                @"_requestIdentifier"
            ]);

    id notification = nil;

    @try {

        notification =
            [request valueForKey:@"notification"];

    } @catch (__unused id exception) {
    }

    if (!notification) {

        @try {

            notification =
                [request valueForKey:@"_notification"];

        } @catch (__unused id exception) {
        }
    }

    UNNotificationContent *content = nil;

    if ([notification
            isKindOfClass:UNNotification.class]) {

        content =
            ((UNNotification *)notification)
                .request.content;

    } else if ([notification
                   isKindOfClass:
                       UNNotificationRequest.class]) {

        content =
            ((UNNotificationRequest *)notification)
                .content;
    }

    if (content) {

        item.title =
            content.title ?: @"";

        item.body =
            content.body ?: @"";

        /*
         * iOS 17+: prefer sourceBundleIdentifier from request,
         * since userInfo rarely contains bundleID.
         */
        NSString *bundleID =
            DINGetString(
                request,
                @[
                    @"sourceBundleIdentifier",
                    @"sectionIdentifier"
                ]);

        if (!bundleID.length) {

            NSDictionary *userInfo =
                content.userInfo;

            bundleID = userInfo[@"bundleID"];

            if (![bundleID isKindOfClass:NSString.class]) {

                bundleID =
                    userInfo[@"bundleIdentifier"];
            }
        }

        item.bundleID =
            [bundleID isKindOfClass:NSString.class]
                ? bundleID
                : @"";
    }

    if (!item.title.length) {

        item.title =
            DINGetString(
                request,
                @[
                    @"title",
                    @"alertTitle"
                ]);
    }

    if (!item.body.length) {

        item.body =
            DINGetString(
                request,
                @[
                    @"body",
                    @"alertBody"
                ]);
    }

    if (!item.bundleID.length) {

        item.bundleID =
            DINGetString(
                request,
                @[
                    @"bundleIdentifier",
                    @"bundleID",
                    @"sourceBundleIdentifier"
                ]);
    }

    if (!item.requestID.length) {

        item.requestID =
            [NSString stringWithFormat:@"%p", request];
    }

    if (!item.title.length &&
        !item.body.length) {

        return nil;
    }

    return item;
}

#pragma mark - SpringBoard Hook

%hook SBBannerController

- (void)presentBannerWithRequest:(id)request {

    NSLog(@"[DIN] SBBannerController presentBannerWithRequest: hit");

    /*
     * Disabled = completely preserve normal iOS behavior.
     */
    if (!DINEnabled()) {

        %orig;

        return;
    }

    DINNotificationItem *item =
        DINCreateItemFromRequest(request);

    if (!item) {

        %orig;

        return;
    }

    /*
     * Send the notification to our Dynamic Island.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            [[DINIslandController sharedController]
                enqueueNotification:item];
        });

    /*
     * Do not call %orig to suppress the default Banner.
     */
    return;
}

%end

#pragma mark - Constructor

%ctor {

    /*
     * Only inject into SpringBoard.
     */
    NSString *bundleID =
        [NSBundle mainBundle].bundleIdentifier;

    if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            DINIslandController *controller =
                [DINIslandController sharedController];

            [controller createWindowIfNeeded];
        });
}
