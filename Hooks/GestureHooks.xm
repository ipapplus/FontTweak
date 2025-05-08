// GestureHooks.xm
// 通过双指双击手势打开字体设置页面

#import <UIKit/UIKit.h>
#import "../Controllers/CSFontSettingsViewController.h"

%hook UIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 创建多指轻拍手势识别器
        UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFontSettingsGesture:)];
        doubleTapGesture.numberOfTapsRequired = 2;     // 需要双击
        doubleTapGesture.numberOfTouchesRequired = 2;  // 需要双指
        
        // 设置低优先级避免干扰其他手势
        doubleTapGesture.delaysTouchesBegan = NO;
        doubleTapGesture.delaysTouchesEnded = NO;
        doubleTapGesture.cancelsTouchesInView = NO;
        
        // 添加手势识别器到主窗口
        [window addGestureRecognizer:doubleTapGesture];
        
        NSLog(@"[FontTweak] 已注册双指双击手势");
    });
    
    return window;
}

// 处理手势事件，打开字体设置页面
%new
- (void)handleFontSettingsGesture:(UITapGestureRecognizer *)gesture {
    // 振动反馈
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback prepare];
    [feedback impactOccurred];
    
    // 查找顶层视图控制器
    UIViewController *topController = nil;
    UIWindow *keyWindow = nil;
    
    // iOS 13+ 获取关键窗口
    if (@available(iOS 13.0, *)) {
        NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    }
    
    // 获取根控制器
    if (keyWindow) {
        topController = keyWindow.rootViewController;
        
        // 递归查找最顶层的控制器
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        
        // 如果是导航控制器，取最顶层的控制器
        if ([topController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)topController;
            if (navController.viewControllers.count > 0) {
                topController = navController.topViewController;
            }
        }
        
        // 如果是TabBar控制器，取当前选中的控制器
        if ([topController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tabController = (UITabBarController *)topController;
            topController = tabController.selectedViewController;
            
            // 如果选中的是导航控制器，取其顶层控制器
            if ([topController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController *)topController;
                if (navController.viewControllers.count > 0) {
                    topController = navController.topViewController;
                }
            }
        }
    }
    
    // 如果已经找到顶层控制器，显示字体设置页面
    if (topController) {
        NSLog(@"[FontTweak] 检测到双指双击手势，直接打开字体设置页面");
        
        // 直接创建并配置字体设置控制器
        CSFontSettingsViewController *fontVC = [[CSFontSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        fontVC.title = @"字体设置";
        
        // 创建导航控制器
        UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:fontVC];
        
        // 设置模态展示样式
        if (@available(iOS 13.0, *)) {
            navVC.modalPresentationStyle = UIModalPresentationFormSheet;
        } else {
            navVC.modalPresentationStyle = UIModalPresentationPageSheet;
        }
        
        // 模态展示控制器
        [topController presentViewController:navVC animated:YES completion:nil];
    }
}

%end 