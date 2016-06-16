//
//  JFPlayerView.h
//  JFPlayer
//
//  Created by fan on 16/6/16.
//  Copyright © 2016年 fan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JFPlayerView : UIView

@property (nonatomic, strong, readonly) UIView* topView;
@property (nonatomic, strong, readonly) UIButton* backBtn;
@property (nonatomic, strong, readonly) UILabel* titleLabel;
@property (nonatomic, strong, readonly) UILabel* timeLabel;
@property (nonatomic, strong, readonly) UIButton* downloadBtn;
@property (nonatomic, strong, readonly) UIImageView* batteryImageView;              // 封装

@property (nonatomic, strong, readonly) UIButton* lockBtn;
@property (nonatomic, strong, readonly) UIButton* vrBtn;

@property (nonatomic, strong, readonly) UIView* bottomView;
@property (nonatomic, strong, readonly) UIButton* playStateBtn;
@property (nonatomic, strong, readonly) UILabel* progressLabel;
@property (nonatomic, strong, readonly) UIView* progressView;
@property (nonatomic, strong, readonly) UIButton* fullBtn;

// 当前是否是全屏
@property (nonatomic, assign, getter=isFullModel) BOOL fullModel;

- (void)showInWindow;

@end
