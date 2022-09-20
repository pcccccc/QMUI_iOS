//
//  QMUIEmotionHeaderView.h
//  QMUIKit
//
//  Created by pangchong on 2022/9/20.
//

#import <UIKit/UIKit.h>
#import "QMUIEmotionView.h"

NS_ASSUME_NONNULL_BEGIN

@interface QMUIEmotionHeaderView : UICollectionViewCell

@property(nonatomic, strong) QMUIEmotionPageView *emotionPageView;

@property(nonatomic, strong) UILabel *recentlyLabel;

@property(nonatomic, strong) UILabel *allLabel;

@end

NS_ASSUME_NONNULL_END
