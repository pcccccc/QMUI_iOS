//
//  QMUIEmotionHeaderView.m
//  QMUIKit
//
//  Created by pangchong on 2022/9/20.
//

#import "QMUIEmotionHeaderView.h"

@implementation QMUIEmotionHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        
        _recentlyLabel = [[UILabel alloc] init];
        _recentlyLabel.text = @"最近使用";
        _recentlyLabel.textColor = [UIColor colorWithRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1];
        _recentlyLabel.font = [UIFont systemFontOfSize:12];
        [self addSubview:_recentlyLabel];
        _recentlyLabel.frame = CGRectMake(15, 0, 150, 12);
        
        _emotionPageView = [[QMUIEmotionPageView alloc] init];
        _emotionPageView.frame = CGRectMake(0, CGRectGetMaxY(_recentlyLabel.frame), self.frame.size.width, 50);
        [self addSubview:_emotionPageView];
        
        _allLabel = [[UILabel alloc] init];
        _allLabel.text = @"全部表情";
        _allLabel.textColor = [UIColor colorWithRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1];
        _allLabel.font = [UIFont systemFontOfSize:12];
        [self addSubview:_allLabel];
        _allLabel.frame = CGRectMake(15, CGRectGetMaxY(_emotionPageView.frame) + 12, 150, 12);
    }
    return self;
}

@end
