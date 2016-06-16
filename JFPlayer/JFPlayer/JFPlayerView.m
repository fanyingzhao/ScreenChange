//
//  JFPlayerView.m
//  JFPlayer
//
//  Created by fan on 16/6/16.
//  Copyright © 2016年 fan. All rights reserved.
//

#import "JFPlayerView.h"
#import "JFMacro.h"

@interface JFPlayerView ()
{
    CGRect _originRect;
}
@property (nonatomic, strong) UIView* topView;
@property (nonatomic, strong) UIButton* backBtn;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UILabel* timeLabel;
@property (nonatomic, strong) UIButton* downloadBtn;
@property (nonatomic, strong) UIImageView* batteryImageView;              // 封装

@property (nonatomic, strong) UIButton* lockBtn;
@property (nonatomic, strong) UIButton* vrBtn;

@property (nonatomic, strong) UIView* bottomView;
@property (nonatomic, strong) UIButton* playStateBtn;
@property (nonatomic, strong) UILabel* progressLabel;
@property (nonatomic, strong) UIView* progressView;
@property (nonatomic, strong) UIButton* fullBtn;
@end

@implementation JFPlayerView

#pragma mark - lifecirlce
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        _originRect = frame;
        
        [self addTopView];
        [self addBottomView];
    }
    
    return self;
}

#pragma mark - ui
- (void)addTopView
{
    _topView = [[UIView alloc] init];
    [self addSubview:_topView];
    
    _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_backBtn setBackgroundImage:[UIImage imageNamed:@"btn_camera retum_normal"] forState:UIControlStateNormal];
    [_backBtn setBackgroundImage:[UIImage imageNamed:@"btn_camera retum_pressed"] forState:UIControlStateHighlighted];
    [_topView addSubview:_backBtn];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.text = @"嘿嘿嘿";
    [_topView addSubview:_titleLabel];
    
    _downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_downloadBtn setBackgroundImage:[UIImage imageNamed:@"btn_download_normal"] forState:UIControlStateNormal];
    [_downloadBtn setBackgroundImage:[UIImage imageNamed:@"btn_download_pressed"] forState:UIControlStateHighlighted];
    [_downloadBtn addTarget:self action:@selector(downloadBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_topView addSubview:_downloadBtn];
}

- (void)addLockBtn
{
    
}

- (void)addVrBtn
{
    
}

- (void)addBottomView
{
    _bottomView = [[UIView alloc] init];
    [self addSubview:_bottomView];
    
    _progressLabel = [[UILabel alloc] init];
    _progressLabel.text = @"00:12/02:35";
    [_bottomView addSubview:_progressLabel];
    
    _fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _fullBtn.backgroundColor = [UIColor greenColor];
    [_fullBtn addTarget:self action:@selector(fullBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_fullBtn];
    
    _progressView = [[UIView alloc] init];
    _progressView.backgroundColor = [UIColor blueColor];
    [_bottomView addSubview:_progressView];
}

- (void)updatePlayerUI
{
    if (self.isFullModel)
    {
        CGFloat height = Application_Landscapte_Height;
        CGFloat width = Application_Landscapte_Width;
        
        [UIView animateWithDuration:.3 animations:^{
            
            self.frame = ({
                CGRect rect;
                rect.size.width = width;
                rect.size.height = height;
                rect.origin.x = (height - width) / 2;
                rect.origin.y = (width - height) / 2;
                rect;
            });
            [self setNeedsLayout];
            [self layoutIfNeeded];
            self.transform = CGAffineTransformMakeRotation(M_PI_2);

        } completion:^(BOOL finished) {
            
        }];
    }
    else
    {
        [UIView animateWithDuration:0.3 animations:^{
            
            self.transform = CGAffineTransformIdentity;
            self.frame = _originRect;
            [self setNeedsLayout];
            [self layoutIfNeeded];
            
        } completion:^(BOOL finished) {
            
        }];
    }
}

#pragma mark - layout
- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _topView.frame = ({
        CGRect rect;
        rect.size.width = CGRectGetWidth(self.frame);
        rect.size.height = 100;
        rect.origin.x = rect.origin.y = 0;
        rect;
    });
    _backBtn.frame = ({
        CGRect rect;
        rect.size.width = rect.size.height = 44;
        rect.origin.x = 23;
        rect.origin.y = 20;
        rect;
    });
    _downloadBtn.frame = ({
        CGRect rect;
        rect.size = _backBtn.frame.size;
        rect.origin.x = CGRectGetWidth(self.frame) - CGRectGetWidth(rect) - 20;
        rect.origin.y = CGRectGetMinY(_backBtn.frame);
        rect;
    });
    
    _bottomView.frame = ({
        CGRect rect;
        rect.size.width = CGRectGetWidth(self.frame);
        rect.size.height = 40;
        rect.origin.x = 0;
        rect.origin.y = CGRectGetHeight(self.frame) - CGRectGetHeight(rect);
        rect;
    });
    _progressLabel.frame = ({
        CGRect rect;
        rect.size.width = 100;
        rect.size.height = 20;
        rect.origin.y = 0;
        rect.origin.x = 0;
        rect;
    });
    _fullBtn.frame = ({
        CGRect rect;
        rect.size.width = rect.size.height = 44;
        rect.origin.x = CGRectGetWidth(self.frame) - CGRectGetWidth(rect) - 20;
        rect.origin.y = 0;
        rect;
    });
    _progressView.frame = ({
        CGRect rect;
        rect.origin.x = CGRectGetMaxX(_progressLabel.frame);
        rect.origin.y = 0;
        rect.size.width = CGRectGetMinX(_fullBtn.frame) - CGRectGetMinX(rect);
        rect.size.height = CGRectGetHeight(_bottomView.frame);
        rect;
    });
}

#pragma mark - funcs
- (void)showInWindow
{
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) {
        keyWindow = [[[UIApplication sharedApplication] windows] firstObject];
    }
    [keyWindow addSubview:self];
    self.alpha = 0.0;
    [UIView animateWithDuration:3 animations:^{
        self.alpha = 1.0;
    } completion:^(BOOL finished) {
        
    }];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
}

#pragma mark - events
- (void)downloadBtnClick:(UIButton*)sender
{
    
}

- (void)fullBtnClick:(UIButton*)sender
{
    self.fullModel = !self.fullModel;
    // 禁用按钮，界面改变完毕恢复
//    sender.enabled = NO;
    
    [self updatePlayerUI];
}

@end
