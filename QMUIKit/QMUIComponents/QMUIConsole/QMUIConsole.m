/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  QMUIConsole.m
//  QMUIKit
//
//  Created by MoLice on 2019/J/11.
//

#import "QMUIConsole.h"
#import "QMUICore.h"
#import "NSParagraphStyle+QMUI.h"
#import "UIView+QMUI.h"
#import "UIWindow+QMUI.h"
#import "UIColor+QMUI.h"
#import "QMUITextView.h"

/// 定义一个 class 只是为了在 Lookin 里表达这是一个 console window 而已，不需要实现什么东西
@interface QMUIConsoleWindow : UIWindow
@end

@implementation QMUIConsoleWindow

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = nil;
        if (QMUICMIActivated) {
            self.windowLevel = UIWindowLevelQMUIConsole;
        } else {
            self.windowLevel = 1;
        }
        self.qmui_capturesStatusBarAppearance = NO;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // 当显示 QMUIConsole 时，点击空白区域，consoleViewController hitTest 会 return nil，从而将事件传递给 window，再由 window hitTest return  nil 来把事件传递给 UIApplication.delegate.window。但在 iPad 12-inch 里，当 consoleViewController hitTest return nil 后，事件会错误地传递给 consoleViewController.view.superview（而不是 consoleWindow），不清楚原因，暂时做一下保护
    // https://github.com/Tencent/QMUI_iOS/issues/1169
    UIView *originalView = [super hitTest:point withEvent:event];
    return originalView == self || originalView == self.rootViewController.view.superview ? nil : originalView;
}

@end

@interface QMUIConsole ()

@property(nonatomic, strong) QMUIConsoleWindow *consoleWindow;
@property(nonatomic, strong) QMUIConsoleViewController *consoleViewController;
@end

@implementation QMUIConsole

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static QMUIConsole *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
        instance.canShow = IS_DEBUG;
        instance.showConsoleAutomatically = YES;
        instance.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.8];
        instance.textAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:12],
                                    NSForegroundColorAttributeName: [UIColor whiteColor],
                                    NSParagraphStyleAttributeName: ({
                                        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle qmui_paragraphStyleWithLineHeight:16];
                                        paragraphStyle.paragraphSpacing = 8;
                                        paragraphStyle;
                                    }),
                                    };
        instance.timeAttributes = ({
            NSMutableDictionary<NSAttributedStringKey, id> *attributes = instance.textAttributes.mutableCopy;
            attributes[NSForegroundColorAttributeName] = [attributes[NSForegroundColorAttributeName] qmui_colorWithAlpha:.6 backgroundColor:instance.backgroundColor];
            attributes.copy;
        });
        instance.searchResultHighlightedBackgroundColor = [UIColorBlue colorWithAlphaComponent:.8];
    });
    return instance;
}

+ (instancetype)appearance {
    return [self sharedInstance];
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    return [self sharedInstance];
}

+ (void)logWithLevel:(NSString *)level name:(NSString *)name logString:(id)logString {
    QMUIConsole *console = [QMUIConsole sharedInstance];
    if (!QMUIConsole.sharedInstance.canShow) return;
    [console initConsoleWindowIfNeeded];
    [console.consoleViewController logWithLevel:level name:name logString:logString];
    if (console.showConsoleAutomatically) {
        [QMUIConsole show];
    }
}

+ (void)log:(id)logString {
    [self logWithLevel:nil name:nil logString:logString];
}

+ (void)clear {
    [[QMUIConsole sharedInstance].consoleViewController clear];
}

+ (void)show {
    QMUIConsole *console = [QMUIConsole sharedInstance];
    if (console.canShow) {
        
        if (!console.consoleWindow.hidden) return;
        
        // 在某些情况下 show 的时候刚好界面正在做动画，就可能会看到 consoleWindow 从左上角展开的过程（window 默认背景色是黑色的），所以这里做了一些小处理
        // https://github.com/Tencent/QMUI_iOS/issues/743
        [UIView performWithoutAnimation:^{
            [console initConsoleWindowIfNeeded];
            console.consoleWindow.alpha = 0;
            console.consoleWindow.hidden = NO;
        }];
        [UIView animateWithDuration:.25 delay:.2 options:QMUIViewAnimationOptionsCurveOut animations:^{
            console.consoleWindow.alpha = 1;
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
                for (UIWindow *window in frontToBackWindows) {
                    BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
                    BOOL windowIsVisible = !window.hidden && window.alpha > 0;
                    BOOL windowLevelNormal = window.windowLevel == UIWindowLevelNormal;
                    if (windowOnMainScreen && windowIsVisible && windowLevelNormal) {
                        [window addSubview:console.consoleWindow];
                        break;
                    }
                }
                
            }];
        } completion:nil];
    }
}

+ (void)hide {
    [QMUIConsole sharedInstance].consoleWindow.hidden = YES;
}

- (void)initConsoleWindowIfNeeded {
    if (!self.consoleWindow) {
        self.consoleWindow = [[QMUIConsoleWindow alloc] init];
        self.consoleViewController = [[QMUIConsoleViewController alloc] init];
        self.consoleWindow.rootViewController = self.consoleViewController;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    _backgroundColor = backgroundColor;
    self.consoleViewController.backgroundColor = backgroundColor;
}

@end
