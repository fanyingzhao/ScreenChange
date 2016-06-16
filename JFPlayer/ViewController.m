//
//  ViewController.m
//  JFPlayer
//
//  Created by fan on 16/6/16.
//  Copyright © 2016年 fan. All rights reserved.
//

#import "ViewController.h"
#import "JFPlayerView.h"

@interface ViewController ()
{
    JFPlayerView* playerView;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    playerView = [[JFPlayerView alloc] initWithFrame:({
        CGRect rect;
        rect.size.width = self.view.frame.size.width;
        rect.size.height = CGRectGetWidth(rect) / 16 * 9;
        rect.origin.x = rect.origin.y = 0;
        rect;
    })];
    playerView.backgroundColor = [UIColor orangeColor];
    
    [self.view addSubview:playerView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            
//            [playerView showInWindow];
//
//        });
//    });
}

@end
