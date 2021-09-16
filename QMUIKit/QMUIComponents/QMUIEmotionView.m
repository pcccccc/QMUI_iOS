/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2020 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  QMUIEmotionView.m
//  qmui
//
//  Created by QMUI Team on 16/9/6.
//

#import "QMUIEmotionView.h"
#import "QMUICore.h"
#import "QMUIButton.h"
#import "UIView+QMUI.h"
#import "UIScrollView+QMUI.h"
#import "UIControl+QMUI.h"
#import "UIImage+QMUI.h"
#import "QMUILog.h"
#import "QMUILabel.h"


@implementation QMUIEmotion

+ (instancetype)emotionWithIdentifier:(NSString *)identifier displayName:(NSString *)displayName {
    QMUIEmotion *emotion = [[self alloc] init];
    emotion.identifier = identifier;
    emotion.displayName = displayName;
    return emotion;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, identifier: %@, displayName: %@", [super description], self.identifier, self.displayName];
}

@end

@class QMUIEmotionPageView;

@protocol QMUIEmotionPageViewDelegate <NSObject>

@optional
- (void)emotionPageView:(QMUIEmotionPageView *)emotionPageView didSelectEmotion:(QMUIEmotion *)emotion atIndex:(NSInteger)index;
- (void)didSelectDeleteButtonInEmotionPageView:(QMUIEmotionPageView *)emotionPageView;

@end

/// 表情面板每一页的cell，在drawRect里将所有表情绘制上去，同时自带一个末尾的删除按钮
@interface QMUIEmotionPageView : UICollectionViewCell

@property(nonatomic, weak) QMUIEmotionView<QMUIEmotionPageViewDelegate> *delegate;

/// 表情被点击时盖在表情上方用于表示选中的遮罩
@property(nonatomic, strong) UIView *emotionSelectedBackgroundView;

/// 表情面板右下角的删除按钮
@property(nonatomic, strong) QMUIButton *deleteButton;

/// 分配给当前pageView的所有表情
@property(nonatomic, copy) NSArray<QMUIEmotion *> *emotions;

/// 记录当前pageView里所有表情的可点击区域的rect，在drawRect:里更新，在tap事件里使用
@property(nonatomic, strong) NSMutableArray<NSValue *> *emotionHittingRects;

/// 负责实现表情的点击
@property(nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

/// 负责实现表情的长按
@property(nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

/// 整个pageView内部的padding
@property(nonatomic, assign) UIEdgeInsets padding;

/// 每个pageView能展示表情的行数
@property(nonatomic, assign) NSInteger numberOfRows;

/// 每个表情的绘制区域大小，表情图片最终会以UIViewContentModeScaleAspectFit的方式撑满这个大小。表情计算布局时也是基于这个大小来算的。
@property(nonatomic, assign) CGSize emotionSize;

/// 点击表情时出现的遮罩要在表情所在的矩形位置拓展多少空间，负值表示遮罩比emotionSize更大，正值表示遮罩比emotionSize更小。最终判断表情点击区域时也是以拓展后的区域来判定的
@property(nonatomic, assign) UIEdgeInsets emotionSelectedBackgroundExtension;

/// 表情与表情之间的水平间距的最小值，实际值可能比这个要大一点（pageView会把剩余空间分配到表情的水平间距里）
@property(nonatomic, assign) CGFloat minimumEmotionHorizontalSpacing;

/// debug模式会把表情的绘制矩形显示出来
@property(nonatomic, assign) BOOL debug;

@property(nonatomic, strong) UIView *hintView;

@end

@implementation QMUIEmotionPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColorClear;
        
        self.emotionSelectedBackgroundView = [[UIView alloc] init];
        self.emotionSelectedBackgroundView.userInteractionEnabled = NO;
        self.emotionSelectedBackgroundView.backgroundColor = UIColorMakeWithRGBA(0, 0, 0, .16);
        self.emotionSelectedBackgroundView.layer.cornerRadius = 3;
        self.emotionSelectedBackgroundView.alpha = 0;
        [self addSubview:self.emotionSelectedBackgroundView];
        
        self.deleteButton = [[QMUIButton alloc] init];
        self.deleteButton.adjustsButtonWhenHighlighted = NO;// 去掉QMUIButton默认的高亮动画，从而加快连续快速点击的响应速度
        self.deleteButton.qmui_automaticallyAdjustTouchHighlightedInScrollView = YES;
        [self.deleteButton addTarget:self action:@selector(handleDeleteButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.deleteButton];
        
        self.emotionHittingRects = [[NSMutableArray alloc] init];
        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGestureRecognizer:)];
        [self addGestureRecognizer:self.tapGestureRecognizer];
        
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecoginzer:)];
        [self addGestureRecognizer:self.longPressGestureRecognizer];
        
        self.hintView = [[UIView alloc] init];
        self.hintView.layer.cornerRadius = 5;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // 删除按钮必定布局到最后一个表情的位置，且与表情上下左右居中
    [self.deleteButton sizeToFit];
    self.deleteButton.frame = CGRectSetXY(self.deleteButton.frame, CGRectGetWidth(self.bounds) - self.padding.right - CGRectGetWidth(self.deleteButton.frame) - (self.emotionSize.width - CGRectGetWidth(self.deleteButton.frame)) / 2.0, CGRectGetHeight(self.bounds) - self.padding.bottom - CGRectGetHeight(self.deleteButton.frame) - (self.emotionSize.height - CGRectGetHeight(self.deleteButton.frame)) / 2.0);
}

- (void)drawRect:(CGRect)rect {
    [self.emotionHittingRects removeAllObjects];
    
    CGSize contentSize = CGRectInsetEdges(self.bounds, self.padding).size;
    NSInteger emotionCountPerRow = (contentSize.width + self.minimumEmotionHorizontalSpacing) / (self.emotionSize.width + self.minimumEmotionHorizontalSpacing);
    CGFloat emotionHorizontalSpacing = flat((contentSize.width - emotionCountPerRow * self.emotionSize.width) / (emotionCountPerRow - 1));
    CGFloat emotionVerticalSpacing = flat((contentSize.height - self.numberOfRows * self.emotionSize.height) / (self.numberOfRows - 1));
    
    CGPoint emotionOrigin = CGPointZero;
    for (NSInteger i = 0, l = self.emotions.count; i < l; i++) {
        NSInteger row = i / emotionCountPerRow;
        emotionOrigin.x = self.padding.left + (self.emotionSize.width + emotionHorizontalSpacing) * (i % emotionCountPerRow);
        emotionOrigin.y = self.padding.top + (self.emotionSize.height + emotionVerticalSpacing) * row;
        QMUIEmotion *emotion = self.emotions[i];
        CGRect emotionRect = CGRectMake(emotionOrigin.x, emotionOrigin.y, self.emotionSize.width, self.emotionSize.height);
        CGRect emotionHittingRect = CGRectInsetEdges(emotionRect, self.emotionSelectedBackgroundExtension);
        [self.emotionHittingRects addObject:[NSValue valueWithCGRect:emotionHittingRect]];
        [self drawImage:emotion.image inRect:emotionRect];
    }
}

- (void)drawImage:(UIImage *)image inRect:(CGRect)contextRect {
    CGSize imageSize = image.size;
    CGFloat horizontalRatio = CGRectGetWidth(contextRect) / imageSize.width;
    CGFloat verticalRatio = CGRectGetHeight(contextRect) / imageSize.height;
    // 表情图片按UIViewContentModeScaleAspectFit的方式来绘制
    CGFloat ratio = fmin(horizontalRatio, verticalRatio);
    CGRect drawingRect = CGRectZero;
    drawingRect.size.width = imageSize.width * ratio;
    drawingRect.size.height = imageSize.height * ratio;
    drawingRect = CGRectSetXY(drawingRect, CGRectGetMinXHorizontallyCenter(contextRect, drawingRect), CGRectGetMinYVerticallyCenter(contextRect, drawingRect));
    if (self.debug) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetLineWidth(context, PixelOne);
        CGContextSetStrokeColorWithColor(context, UIColorTestRed.CGColor);
        CGContextStrokeRect(context, CGRectInset(contextRect, PixelOne / 2.0, PixelOne / 2.0));
    }
    [image drawInRect:drawingRect];
}

- (void)handleTapGestureRecognizer:(UITapGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:self];
    for (NSInteger i = 0; i < self.emotionHittingRects.count; i ++) {
        CGRect rect = [self.emotionHittingRects[i] CGRectValue];
        if (CGRectContainsPoint(rect, location)) {
            QMUIEmotion *emotion = self.emotions[i];
            self.emotionSelectedBackgroundView.frame = rect;
            [UIView animateWithDuration:.08 animations:^{
                self.emotionSelectedBackgroundView.alpha = 1;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:.08 animations:^{
                    self.emotionSelectedBackgroundView.alpha = 0;
                } completion:nil];
            }];
            if ([self.delegate respondsToSelector:@selector(emotionPageView:didSelectEmotion:atIndex:)]) {
                [self.delegate emotionPageView:self didSelectEmotion:emotion atIndex:i];
            }
            if (self.debug) {
                QMUILog(NSStringFromClass(self.class), @"点击的是当前页里的第 %@ 个表情，%@", @(i), emotion);
            }
            return;
        }
    }
}

- (void)handleLongPressGestureRecoginzer:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint location = [gestureRecognizer locationInView:self];
        
        for (NSInteger i = 0; i < self.emotionHittingRects.count; i ++) {
            CGRect rect = [self.emotionHittingRects[i] CGRectValue];
            if (CGRectContainsPoint(rect, location)) {
                QMUIEmotion *emotion = self.emotions[i];
                self.emotionSelectedBackgroundView.frame = rect;
                [UIView animateWithDuration:.08 animations:^{
                    self.emotionSelectedBackgroundView.alpha = 1;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:.08 animations:^{
                        self.emotionSelectedBackgroundView.alpha = 0;
                    } completion:nil];
                    
                    self.hintView.frame = CGRectMake(rect.origin.x, rect.origin.y - rect.size.width - 14, rect.size.width, rect.size.height + 14);
                    self.hintView.backgroundColor = UIColor.whiteColor;
                    self.hintView.layer.shadowColor = UIColor.grayColor.CGColor;
                    // 阴影偏移，默认(0, -3)
                    self.hintView.layer.shadowOffset = CGSizeMake(0,0);
                    // 阴影透明度，默认0
                    self.hintView.layer.shadowOpacity = 0.5;
                    // 阴影半径，默认3
                    self.hintView.layer.shadowRadius = 5;
                    
                    [self addSubview:self.hintView];
                    self.hintView.frame = CGRectMake([self relativeFrameForScreenWithView:self.hintView].origin.x - 2, [self relativeFrameForScreenWithView:self.hintView].origin.y - 18, rect.size.width + 4, rect.size.height + 18);
                    [self.hintView removeFromSuperview];
                    
                    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 4, 30, 30)];
                    imgView.image = emotion.image;
                    [self.hintView addSubview:imgView];
                    
                    QMUILabel *titleLabel = [[QMUILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(imgView.frame), self.hintView.frame.size.width, 13)];
                    titleLabel.font = UIFontMake(12);
                    titleLabel.textAlignment = NSTextAlignmentCenter;
                    
                    NSString *name = [emotion.displayName substringWithRange:NSMakeRange(1, emotion.displayName.length - 2)];
                    titleLabel.text = name;
                    titleLabel.textColor = [UIColor colorWithRed:178 / 255.0 green:180 / 255.0 blue:184 / 255.0 alpha:1];
                    [self.hintView addSubview:titleLabel];
                    
                    [[UIApplication sharedApplication].keyWindow addSubview:self.hintView];
                    CGFloat height = rect.size.height + 18;
                    CGFloat width = rect.size.width + 4;
                    UIBezierPath *path = [UIBezierPath bezierPath];
                    path.lineWidth = 1;
                    path.lineCapStyle = kCGLineCapRound;
                    path.lineJoinStyle = kCGLineJoinRound;
                    [path moveToPoint:CGPointMake(width/2 - 5, height)];
                    [path addLineToPoint:CGPointMake(width/2 - 5, height)];
                    [path addLineToPoint:CGPointMake(width/2, 6 + height)];
                    [path addLineToPoint:CGPointMake(width/2 + 5, height)];
                    [path closePath];
                    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
                    layer.path = path.CGPath;
                    layer.fillColor = UIColor.whiteColor.CGColor;
                    [self.hintView.layer addSublayer:layer];
                }];

                NSLog(@"点击的是当前页里的第 %@ 个表情，%@", @(i), emotion);

                return;
            }
        }
    }else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {

        dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 0.08 * NSEC_PER_SEC);
        dispatch_after(time, dispatch_get_main_queue(), ^{
            //执行操作
            [self.hintView removeFromSuperview];
            for (UIView *view in self.hintView.subviews) {
                
                [view removeFromSuperview];
            }
        });
       
    }
}

/**
 *  计算一个view相对于屏幕的坐标
 */
- (CGRect)relativeFrameForScreenWithView:(UIView *)someView {
    UIView *view = someView;
    CGFloat x = .0;
    CGFloat y = .0;
    while (view != [UIApplication sharedApplication].keyWindow && nil != view) {
        x += view.frame.origin.x;
        y += view.frame.origin.y;
        view = view.superview;
        if ([view isKindOfClass:[UIScrollView class]]) {
            x -= ((UIScrollView *) view).contentOffset.x;
            y -= ((UIScrollView *) view).contentOffset.y;
        }
    }
    return CGRectMake(x, y, self.frame.size.width, self.frame.size.height);
}

- (void)handleDeleteButtonEvent:(QMUIButton *)deleteButton {
    if ([self.delegate respondsToSelector:@selector(didSelectDeleteButtonInEmotionPageView:)]) {
        [self.delegate didSelectDeleteButtonInEmotionPageView:self];
    }
}

@end

@interface QMUIEmotionView ()<QMUIEmotionPageViewDelegate>

@property(nonatomic, strong) NSMutableArray<NSArray<QMUIEmotion *> *> *pagedEmotions;
@property(nonatomic, assign) BOOL debug;
@end

@implementation QMUIEmotionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self didInitializedWithFrame:frame];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self didInitializedWithFrame:CGRectZero];
    }
    return self;
}

- (void)didInitializedWithFrame:(CGRect)frame {
    self.debug = NO;
    
    self.pagedEmotions = [[NSMutableArray alloc] init];
    
    _collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionViewLayout.minimumLineSpacing = 0;
    self.collectionViewLayout.minimumInteritemSpacing = 0;
    self.collectionViewLayout.sectionInset = UIEdgeInsetsZero;
    
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(self.qmui_safeAreaInsets.left, self.qmui_safeAreaInsets.top, CGRectGetWidth(frame) - UIEdgeInsetsGetHorizontalValue(self.qmui_safeAreaInsets), CGRectGetHeight(frame) - UIEdgeInsetsGetVerticalValue(self.qmui_safeAreaInsets)) collectionViewLayout:self.collectionViewLayout];
    self.collectionView.backgroundColor = UIColorClear;
    self.collectionView.scrollsToTop = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[QMUIEmotionPageView class] forCellWithReuseIdentifier:@"page"];
    [self addSubview:self.collectionView];
    
    _pageControl = [[UIPageControl alloc] init];
    [self.pageControl addTarget:self action:@selector(handlePageControlEvent:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.pageControl];
    
//    _sendButton = [[QMUIButton alloc] init];
//    [self.sendButton setTitle:@"发送" forState:UIControlStateNormal];
//    self.sendButton.contentEdgeInsets = UIEdgeInsetsMake(5, 17, 5, 17);
//    [self.sendButton sizeToFit];
//    [self addSubview:self.sendButton];
}

- (void)setEmotions:(NSArray<QMUIEmotion *> *)emotions {
    _emotions = emotions;
    [self pageEmotions];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect collectionViewFrame = CGRectInsetEdges(self.bounds, self.qmui_safeAreaInsets);
    BOOL collectionViewSizeChanged = !CGSizeEqualToSize(collectionViewFrame.size, self.collectionView.bounds.size);
    self.collectionViewLayout.itemSize = collectionViewFrame.size;// 先更新 itemSize 再设置 collectionView.frame，否则会触发系统的 UICollectionViewFlowLayoutBreakForInvalidSizes 断点
    self.collectionView.frame = collectionViewFrame;
    
    if (collectionViewSizeChanged) {
        [self pageEmotions];
    }
    
    self.sendButton.qmui_right = self.qmui_width - self.qmui_safeAreaInsets.right - self.sendButtonMargins.right;
    self.sendButton.qmui_bottom = self.qmui_height - self.qmui_safeAreaInsets.bottom - self.sendButtonMargins.bottom;
    
    CGFloat pageControlHeight = 16;
    CGFloat pageControlMaxX = self.sendButton.qmui_left;
    CGFloat pageControlMinX = self.qmui_width - pageControlMaxX;
    self.pageControl.frame = CGRectMake(pageControlMinX, self.qmui_height - self.qmui_safeAreaInsets.bottom - self.pageControlMarginBottom - pageControlHeight, pageControlMaxX - pageControlMinX, pageControlHeight);
}

- (void)pageEmotions {
    [self.pagedEmotions removeAllObjects];
    self.pageControl.numberOfPages = 0;
    
    if (!CGRectIsEmpty(self.collectionView.bounds) && self.emotions.count && !CGSizeIsEmpty(self.emotionSize)) {
        CGFloat contentWidthInPage = CGRectGetWidth(self.collectionView.bounds) - UIEdgeInsetsGetHorizontalValue(self.paddingInPage);
        NSInteger maximumEmotionCountPerRowInPage = (contentWidthInPage + self.minimumEmotionHorizontalSpacing) / (self.emotionSize.width + self.minimumEmotionHorizontalSpacing);
        NSInteger maximumEmotionCountPerPage = maximumEmotionCountPerRowInPage * self.numberOfRowsPerPage - 1;// 删除按钮占一个表情位置
        NSInteger pageCount = ceil((CGFloat)self.emotions.count / (CGFloat)maximumEmotionCountPerPage);
        for (NSInteger i = 0; i < pageCount; i ++) {
            NSRange emotionRangeForPage = NSMakeRange(maximumEmotionCountPerPage * i, maximumEmotionCountPerPage);
            if (NSMaxRange(emotionRangeForPage) > self.emotions.count) {
                // 最后一页可能不满一整页，所以取剩余的所有表情即可
                emotionRangeForPage.length = self.emotions.count - emotionRangeForPage.location;
            }
            NSArray<QMUIEmotion *> *emotionForPage = [self.emotions objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:emotionRangeForPage]];
            [self.pagedEmotions addObject:emotionForPage];
        }
        self.pageControl.numberOfPages = pageCount;
    }
    
    [self.collectionView reloadData];
    [self.collectionView qmui_scrollToTop];
}

- (void)handlePageControlEvent:(UIPageControl *)pageControl {
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:pageControl.currentPage inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
}

#pragma mark - UIAppearance Setter

- (void)setSendButtonTitleAttributes:(NSDictionary *)sendButtonTitleAttributes {
    _sendButtonTitleAttributes = sendButtonTitleAttributes;
    [self.sendButton setAttributedTitle:[[NSAttributedString alloc] initWithString:[self.sendButton currentTitle] attributes:_sendButtonTitleAttributes] forState:UIControlStateNormal];
}

- (void)setSendButtonBackgroundColor:(UIColor *)sendButtonBackgroundColor {
    _sendButtonBackgroundColor = sendButtonBackgroundColor;
    self.sendButton.backgroundColor = _sendButtonBackgroundColor;
}

- (void)setSendButtonCornerRadius:(CGFloat)sendButtonCornerRadius {
    _sendButtonCornerRadius = sendButtonCornerRadius;
    self.sendButton.layer.cornerRadius = _sendButtonCornerRadius;
}

#pragma mark - <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.pagedEmotions.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    QMUIEmotionPageView *pageView = [collectionView dequeueReusableCellWithReuseIdentifier:@"page" forIndexPath:indexPath];
    pageView.delegate = self;
    pageView.emotions = self.pagedEmotions[indexPath.item];
    pageView.padding = self.paddingInPage;
    pageView.numberOfRows = self.numberOfRowsPerPage;
    pageView.emotionSize = self.emotionSize;
    pageView.emotionSelectedBackgroundExtension = self.emotionSelectedBackgroundExtension;
    pageView.minimumEmotionHorizontalSpacing = self.minimumEmotionHorizontalSpacing;
    [pageView.deleteButton setImage:self.deleteButtonImage forState:UIControlStateNormal];
    [pageView.deleteButton setImage:[self.deleteButtonImage qmui_imageWithAlpha:ButtonHighlightedAlpha] forState:UIControlStateHighlighted];
    pageView.debug = self.debug;
    [pageView setNeedsDisplay];
    return pageView;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.collectionView) {
        NSInteger currentPage = round(scrollView.contentOffset.x / CGRectGetWidth(scrollView.bounds));
        self.pageControl.currentPage = currentPage;
    }
}

#pragma mark - <QMUIEmotionPageViewDelegate>

- (void)emotionPageView:(QMUIEmotionPageView *)emotionPageView didSelectEmotion:(QMUIEmotion *)emotion atIndex:(NSInteger)index {
    if (self.didSelectEmotionBlock) {
        NSInteger index = [self.emotions indexOfObject:emotion];
        self.didSelectEmotionBlock(index, emotion);
    }
}

- (void)didSelectDeleteButtonInEmotionPageView:(QMUIEmotionPageView *)emotionPageView {
    if (self.didSelectDeleteButtonBlock) {
        self.didSelectDeleteButtonBlock();
    }
}

@end

@interface QMUIEmotionView (UIAppearance)

@end

@implementation QMUIEmotionView (UIAppearance)

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setDefaultAppearance];
    });
}

+ (void)setDefaultAppearance {
    QMUIEmotionView *appearance = [QMUIEmotionView appearance];
    appearance.backgroundColor = UIColorForBackground;// 如果先设置了 UIView.appearance.backgroundColor，再使用最传统的 method_exchangeImplementations 交换 UIView.setBackgroundColor 方法，则会 crash。QMUI 这里是在 +initialize 时设置的，业务如果要 hook -[UIView setBackgroundColor:] 则需要比 +initialize 更早才行
    appearance.deleteButtonImage = [QMUIHelper imageWithName:@"QMUI_emotion_delete"];
    appearance.paddingInPage = UIEdgeInsetsMake(18, 18, 65, 18);
    appearance.numberOfRowsPerPage = 4;
    appearance.emotionSize = CGSizeMake(30, 30);
    appearance.emotionSelectedBackgroundExtension = UIEdgeInsetsMake(-3, -3, -3, -3);
    appearance.minimumEmotionHorizontalSpacing = 10;
    appearance.sendButtonTitleAttributes = @{NSFontAttributeName: UIFontMake(15), NSForegroundColorAttributeName: UIColorWhite};
    appearance.sendButtonBackgroundColor = UIColorBlue;
    appearance.sendButtonCornerRadius = 4;
    appearance.sendButtonMargins = UIEdgeInsetsMake(0, 0, 16, 16);
    appearance.pageControlMarginBottom = 22;
    
    UIPageControl *pageControlAppearance = [UIPageControl appearanceWhenContainedInInstancesOfClasses:@[[QMUIEmotionView class]]];
    pageControlAppearance.pageIndicatorTintColor = UIColorMake(210, 210, 210);
    pageControlAppearance.currentPageIndicatorTintColor = UIColorMake(162, 162, 162);
}

@end
