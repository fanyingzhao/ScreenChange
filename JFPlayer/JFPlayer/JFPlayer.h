//
//  JFPlayer.h
//  JFPlayer
//
//  Created by fan on 16/6/2.
//  Copyright © 2016年 fan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
//#import "VideoDrawModel.h"

@class JFPlayer;

@protocol JFVideoPlayerDelegate <NSObject>

@optional
- (void)videoPlayerIsReadyToPlayVideo:(JFPlayer *)videoPlayer;
- (void)videoPlayerStartPlay:(JFPlayer*)videoPlayer;
- (void)videoPlayerDidReachEnd:(JFPlayer *)videoPlayer;
- (void)videoPlayer:(JFPlayer *)videoPlayer timeDidChange:(CMTime)cmTime;
- (void)videoPlayer:(JFPlayer *)videoPlayer loadedTimeRangeDidChange:(float)duration;
- (void)videoPlayerPlaybackBufferEmpty:(JFPlayer *)videoPlayer;
- (void)videoPlayerPlaybackLikelyToKeepUp:(JFPlayer *)videoPlayer;
- (void)videoPlayer:(JFPlayer *)videoPlayer didFailWithError:(NSError *)error;

@end

@interface JFPlayer : NSObject

@property (nonatomic, weak) id<JFVideoPlayerDelegate> delegate;

@property (nonatomic, strong, readonly) AVPlayer *player;
@property (nonatomic, strong, readonly) AVPlayerItem *item;
@property (nonatomic, assign, readonly) CGFloat duration;
@property (nonatomic, assign, readonly) CGFloat currentTime;

@property (nonatomic, assign, getter=isPlaying, readonly) BOOL playing;
@property (nonatomic, assign, getter=isLooping) BOOL looping;
@property (nonatomic, assign, getter=isMuted) BOOL muted;
@property (nonatomic, assign, readonly) BOOL isAtEndTime;
@property (nonatomic, assign) BOOL pauseByUser;                             // 是否被用户暂停

- (void)setURL:(NSURL *)URL;
- (void)setPlayerItem:(AVPlayerItem *)playerItem;
- (void)setAsset:(AVAsset *)asset;

// Playback
- (void)play;
- (void)pause;
- (void)seekToTime:(float)time;
- (void)reset;

// AirPlay
- (void)enableAirplay;
- (void)disableAirplay;
- (BOOL)isAirplayEnabled;

// Time Updates
- (void)enableTimeUpdates; // TODO: need these? no
- (void)disableTimeUpdates;

// Scrubbing
- (void)startScrubbing;
- (void)scrub:(float)time;
- (void)stopScrubbing;

// Volume
- (void)setVolume:(float)volume;
- (void)fadeInVolume;
- (void)fadeOutVolume;

@end
