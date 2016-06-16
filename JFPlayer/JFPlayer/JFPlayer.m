//
//  JFPlayer.m
//  JFPlayer
//
//  Created by fan on 16/6/2.
//  Copyright © 2016年 fan. All rights reserved.
//

#import "JFPlayer.h"

static const float DefaultPlayableBufferLength = 2.0f;
static const float DefaultVolumeFadeDuration = 1.0f;
static const float TimeObserverInterval = 0.01f;

NSString * const kVideoPlayerErrorDomain = @"kVideoPlayerErrorDomain";

#define ONE_FRAME_DURATION 0.03


static void *VideoPlayer_PlayerItemStatusContext = &VideoPlayer_PlayerItemStatusContext;
static void *VideoPlayer_PlayerExternalPlaybackActiveContext = &VideoPlayer_PlayerExternalPlaybackActiveContext;
static void *VideoPlayer_PlayerRateChangedContext = &VideoPlayer_PlayerRateChangedContext;
static void *VideoPlayer_PlayerItemPlaybackLikelyToKeepUp = &VideoPlayer_PlayerItemPlaybackLikelyToKeepUp;
static void *VideoPlayer_PlayerItemPlaybackBufferEmpty = &VideoPlayer_PlayerItemPlaybackBufferEmpty;
static void *VideoPlayer_PlayerItemLoadedTimeRangesContext = &VideoPlayer_PlayerItemLoadedTimeRangesContext;

@interface JFPlayer ()<AVPlayerItemOutputPullDelegate>
{
    NSInteger _timeCount;
    
    BOOL _recevieVideoImageData;                    // 第一次播放一个视频时重置，播放失败重置,播放完毕重置
}
@property (nonatomic, strong, readwrite) AVPlayer *player;
@property (nonatomic, assign, readwrite) CGFloat duration;
@property (nonatomic, assign, readwrite) CGFloat currentTime;
@property (nonatomic, strong) AVPlayerItemVideoOutput* videoOutput;;

@property (nonatomic, assign, getter=isPlaying, readwrite) BOOL playing;
@property (nonatomic, assign, getter=isScrubbing) BOOL scrubbing;
@property (nonatomic, assign, getter=isSeeking) BOOL seeking;
@property (nonatomic, assign) BOOL isAtEndTime;
@property (nonatomic, assign) BOOL shouldPlayAfterScrubbing;

@property (nonatomic, assign) float volumeFadeDuration;
@property (nonatomic, assign) float playableBufferLength;

@property (nonatomic, assign) BOOL isTimingUpdateEnabled;
@property (nonatomic, strong) id timeObserverToken;

@property (nonatomic, strong) AVPlayerItem *item;
@end

@implementation JFPlayer

- (void)dealloc
{
    [self resetPlayerItemIfNecessary];
    
    [self removePlayerObservers];
    
    [self removeTimeObserver];
    
    [self cancelFadeVolume];    
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _volumeFadeDuration = DefaultVolumeFadeDuration;
        _playableBufferLength = DefaultPlayableBufferLength;
        
        [self setupPlayer];
        
        [self addPlayerObservers];
        
        [self setupAudioSession];
        
        
    }
    
    return self;
}

#pragma mark - Setup
- (void)setupPlayer
{
    self.player = [[AVPlayer alloc] init];
    
    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    dispatch_queue_t myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [_videoOutput setDelegate:self queue:myVideoOutputQueue];
    
    // 默认是静音，音频和视频同步后恢复
    self.muted = YES;
    self.looping = NO;
    
    [self setVolume:1.0f];
    [self enableTimeUpdates];
    [self enableAirplay];
}

- (void)setupAudioSession
{
    NSError *categoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
    if (!success)
    {
        NSLog(@"Error setting audio session category: %@", categoryError);
    }
    
    NSError *activeError = nil;
    success = [[AVAudioSession sharedInstance] setActive:YES error:&activeError];
    if (!success)
    {
        NSLog(@"Error setting audio session active: %@", activeError);
    }
}

#pragma mark - Public API
- (void)setURL:(NSURL *)URL
{
    if (URL == nil)
    {
        return;
    }
    
    _recevieVideoImageData = NO;

    [self resetPlayerItemIfNecessary];
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:URL];
    if (!playerItem)
    {
        [self reportUnableToCreatePlayerItem];
        
        return;
    }
    
    [self preparePlayerItem:playerItem];
}

- (void)setPlayerItem:(AVPlayerItem *)playerItem
{
    if (playerItem == nil)
    {
        return;
    }
    
    [self resetPlayerItemIfNecessary];
    
    [self preparePlayerItem:playerItem];
}

- (void)setAsset:(AVAsset *)asset
{
    if (asset == nil)
    {
        return;
    }
    
    [self resetPlayerItemIfNecessary];
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:asset automaticallyLoadedAssetKeys:@[NSStringFromSelector(@selector(tracks))]];
    if (!playerItem)
    {
        [self reportUnableToCreatePlayerItem];
        
        return;
    }
    
    [self preparePlayerItem:playerItem];
}

#pragma mark - BaseDrawModelDelegate
- (CVPixelBufferRef)getVideoBufferPixel
{
    if (!self.playing)
    {
        return NULL;
    }
    
    CVPixelBufferRef pixelBuffer = [_videoOutput copyPixelBufferForItemTime:[self.item currentTime] itemTimeForDisplay:nil];
    
    if (pixelBuffer == NULL) {
        
        _timeCount ++;
        
        if (_timeCount > 100) {
            if (self.player.rate) {
                [self.item removeOutput:_videoOutput];
                _videoOutput = nil;
                
                NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
                _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
                dispatch_queue_t myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
                [_videoOutput setDelegate:self queue:myVideoOutputQueue];
                
                [self.item addOutput:_videoOutput];
                [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
            }
            
            _timeCount = 0;
        }
    }
    else
    {
        // 当第一次有值时回调
        if (!_recevieVideoImageData)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerStartPlay:)])
            {
                [self.delegate videoPlayerStartPlay:self];
            }
            
            _recevieVideoImageData = YES;
        }
    }
    
    return pixelBuffer;
}

#pragma mark - Accessor Overrides

- (void)setMuted:(BOOL)muted
{
    if (self.player)
    {
        self.player.muted = muted;
    }
}

- (BOOL)isMuted
{
    return self.player.isMuted;
}

#pragma mark - Playback

- (void)play
{
    if (self.player.currentItem == nil)
    {
        return;
    }
    
    NSLog(@"尝试播放  status -- %ld",(long)[self.player.currentItem status]);
    self.playing = YES;
    
    if ([self.player.currentItem status] == AVPlayerItemStatusReadyToPlay)
    {
        if ([self isAtEndTime])
        {
            [self restart];
        }
        else
        {
            [self.player play];
        }
        
        NSLog(@"播放");
    }
}

- (void)pause
{
    self.playing = NO;
    
    NSLog(@"暂停");
    
    [self.player pause];
}

- (void)seekToTime:(float)time
{
    if (_seeking)
    {
        return;
    }
    
    if (self.player)
    {
        CMTime cmTime = CMTimeMakeWithSeconds(time, self.player.currentTime.timescale);
        
        if (CMTIME_IS_INVALID(cmTime) || self.player.currentItem.status != AVPlayerStatusReadyToPlay)
        {
            return;
        }
        
        _seeking = YES;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [self.player seekToTime:cmTime completionHandler:^(BOOL finished) {
                
                _isAtEndTime = NO;
                _seeking = NO;
                
                if (finished)
                {
                    _scrubbing = NO;
                }
                
            }];
        });
    }
}

- (void)reset
{
    [self pause];
    [self resetPlayerItemIfNecessary];
}

#pragma mark - Airplay

- (void)enableAirplay
{
    if (self.player)
    {
        self.player.allowsExternalPlayback = YES;
    }
}

- (void)disableAirplay
{
    if (self.player)
    {
        self.player.allowsExternalPlayback = NO;
    }
}

- (BOOL)isAirplayEnabled
{
    return (self.player && self.player.allowsExternalPlayback);
}

#pragma mark - Scrubbing

- (void)startScrubbing
{
    self.scrubbing = YES;
    
    if (self.isPlaying)
    {
        self.shouldPlayAfterScrubbing = YES;
        
        [self pause];
    }
}

- (void)scrub:(float)time
{
    if (self.isScrubbing == NO)
    {
        [self startScrubbing];
    }
    
    [self.player.currentItem cancelPendingSeeks];
    
    [self seekToTime:time];
}

- (void)stopScrubbing
{
    if (self.shouldPlayAfterScrubbing)
    {
        [self play];
        
        self.shouldPlayAfterScrubbing = NO;
    }
    
    self.scrubbing = NO;
}

#pragma mark - funcs


#pragma mark - Time Updates

- (void)enableTimeUpdates
{
    self.isTimingUpdateEnabled = YES;
    
    [self addTimeObserver];
}

- (void)disableTimeUpdates
{
    self.isTimingUpdateEnabled = NO;
    
    [self removeTimeObserver];
}

#pragma mark - Volume

- (void)setVolume:(float)volume
{
    [self cancelFadeVolume];
    
    self.player.volume = volume;
}

- (void)cancelFadeVolume
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeInVolume) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOutVolume) object:nil];
}

- (void)fadeInVolume
{
    if (self.player == nil)
    {
        return;
    }
    
    [self cancelFadeVolume];
    
    if (self.player.volume >= 1.0f - 0.01f)
    {
        self.player.volume = 1.0f;
    }
    else
    {
        self.player.volume += 1.0f/10.0f;
        
        [self performSelector:@selector(fadeInVolume) withObject:nil afterDelay:self.volumeFadeDuration/10.0f];
    }
}

- (void)fadeOutVolume
{
    if (self.player == nil)
    {
        return;
    }
    
    [self cancelFadeVolume];
    
    if (self.player.volume <= 0.01f)
    {
        self.player.volume = 0.0f;
    }
    else
    {
        self.player.volume -= 1.0f/10.0f;
        
        [self performSelector:@selector(fadeOutVolume) withObject:nil afterDelay:self.volumeFadeDuration/10.0f];
    }
}

#pragma mark - Private API

- (void)reportUnableToCreatePlayerItem
{
    if ([self.delegate respondsToSelector:@selector(videoPlayer:didFailWithError:)])
    {
        NSError *error = [NSError errorWithDomain:kVideoPlayerErrorDomain
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey : @"Unable to create AVPlayerItem."}];
        
        [self.delegate videoPlayer:self didFailWithError:error];
        
        _recevieVideoImageData = NO;
    }
}

- (void)resetPlayerItemIfNecessary
{
    if (self.item)
    {
        [self removePlayerItemObservers:self.item];
        [self.item removeOutput:self.videoOutput];
        self.videoOutput = nil;

        [self.player replaceCurrentItemWithPlayerItem:nil];
        
        self.item = nil;
    }
    
    _volumeFadeDuration = DefaultVolumeFadeDuration;
    _playableBufferLength = DefaultPlayableBufferLength;
    
    _playing = NO;
    _isAtEndTime = NO;
    _scrubbing = NO;
}

- (void)preparePlayerItem:(AVPlayerItem *)playerItem
{
    NSParameterAssert(playerItem);
    
    self.item = playerItem;
    
    [self.item addOutput:_videoOutput];
    [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
    
    [self addPlayerItemObservers:playerItem];
    
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
}

- (void)restart
{
    [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        
        _isAtEndTime = NO;
        
        if (self.isPlaying)
        {
            [self play];
        }
        
    }];
}

- (BOOL)isAtEndTime // TODO: this is a fucked up override, seems like something could be wrong [AH]
{
    if (self.player && self.player.currentItem)
    {
        if (_isAtEndTime)
        {
            return _isAtEndTime;
        }
        
        float currentTime = 0.0f;
        if (CMTIME_IS_INVALID(self.player.currentTime) == NO)
        {
            currentTime = CMTimeGetSeconds(self.player.currentTime);
        }
        
        float videoDuration = 0.0f;
        if (CMTIME_IS_INVALID(self.player.currentItem.duration) == NO)
        {
            videoDuration = CMTimeGetSeconds(self.player.currentItem.duration);
        }
        
        if (currentTime > 0.0f && videoDuration > 0.0f)
        {
            if (fabs(currentTime - videoDuration) <= 0.01f)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (float)calcLoadedDuration
{
    float loadedDuration = 0.0f;
    
    if (self.player && self.player.currentItem)
    {
        NSArray *loadedTimeRanges = self.player.currentItem.loadedTimeRanges;
        
        if (loadedTimeRanges && [loadedTimeRanges count])
        {
            CMTimeRange timeRange = [[loadedTimeRanges firstObject] CMTimeRangeValue];
            float startSeconds = CMTimeGetSeconds(timeRange.start);
            float durationSeconds = CMTimeGetSeconds(timeRange.duration);
            
            loadedDuration = startSeconds + durationSeconds;
        }
    }
    
    return loadedDuration;
}

#pragma mark - Player Observers

- (void)addPlayerObservers
{
    [self.player addObserver:self
                  forKeyPath:NSStringFromSelector(@selector(isExternalPlaybackActive))
                     options:NSKeyValueObservingOptionNew
                     context:VideoPlayer_PlayerExternalPlaybackActiveContext];
    
    [self.player addObserver:self
                  forKeyPath:NSStringFromSelector(@selector(rate))
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:VideoPlayer_PlayerRateChangedContext];
}

- (void)removePlayerObservers
{
    @try
    {
        [self.player removeObserver:self
                         forKeyPath:NSStringFromSelector(@selector(isExternalPlaybackActive))
                            context:VideoPlayer_PlayerExternalPlaybackActiveContext];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
    
    @try
    {
        [self.player removeObserver:self
                         forKeyPath:NSStringFromSelector(@selector(rate))
                            context:VideoPlayer_PlayerRateChangedContext];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
}

#pragma mark - PlayerItem Observers

- (void)addPlayerItemObservers:(AVPlayerItem *)playerItem
{
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(status))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                    context:VideoPlayer_PlayerItemStatusContext];
    
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(playbackLikelyToKeepUp))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:VideoPlayer_PlayerItemPlaybackLikelyToKeepUp];
    
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(playbackBufferEmpty))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:VideoPlayer_PlayerItemPlaybackBufferEmpty];
    
    [playerItem addObserver:self
                 forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))
                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                    context:VideoPlayer_PlayerItemLoadedTimeRangesContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}

- (void)removePlayerItemObservers:(AVPlayerItem *)playerItem
{
    [playerItem cancelPendingSeeks];
    
    @try
    {
        [playerItem removeObserver:self
                        forKeyPath:NSStringFromSelector(@selector(status))
                           context:VideoPlayer_PlayerItemStatusContext];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
    
    @try
    {
        [playerItem removeObserver:self
                        forKeyPath:NSStringFromSelector(@selector(playbackLikelyToKeepUp))
                           context:VideoPlayer_PlayerItemPlaybackLikelyToKeepUp];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
    
    @try
    {
        [playerItem removeObserver:self
                        forKeyPath:NSStringFromSelector(@selector(playbackBufferEmpty))
                           context:VideoPlayer_PlayerItemPlaybackBufferEmpty];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
    
    @try
    {
        [playerItem removeObserver:self
                        forKeyPath:NSStringFromSelector(@selector(loadedTimeRanges))
                           context:VideoPlayer_PlayerItemLoadedTimeRangesContext];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception removing observer: %@", exception);
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
}

#pragma mark - Time Observer

- (void)addTimeObserver
{
    if (self.timeObserverToken || self.player == nil)
    {
        return;
    }
    
    __weak typeof (self) weakSelf = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(TimeObserverInterval, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        
        __strong typeof (self) strongSelf = weakSelf;
        if (!strongSelf)
        {
            return;
        }
        
        if ([strongSelf.delegate respondsToSelector:@selector(videoPlayer:timeDidChange:)])
        {
            [strongSelf.delegate videoPlayer:strongSelf timeDidChange:time];
        }
        
    }];
}

- (void)removeTimeObserver
{
    if (self.timeObserverToken == nil)
    {
        return;
    }
    
    if (self.player)
    {
        [self.player removeTimeObserver:self.timeObserverToken];
    }
    
    self.timeObserverToken = nil;
}

#pragma mark - Observer Response

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == VideoPlayer_PlayerRateChangedContext)
    {
        if (self.isScrubbing == NO && self.isPlaying && self.player.rate == 0.0f)
        {
            // TODO: Show loading indicator
        }
    }
    else if (context == VideoPlayer_PlayerItemStatusContext)
    {
        AVPlayerStatus newStatus = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        AVPlayerStatus oldStatus = [[change objectForKey:NSKeyValueChangeOldKey] integerValue];
        
        if (newStatus != oldStatus)
        {
            switch (newStatus)
            {
                case AVPlayerItemStatusUnknown:
                {
                    NSLog(@"Video player Status Unknown");
                    break;
                }
                case AVPlayerItemStatusReadyToPlay:
                {
                    if ([self.delegate respondsToSelector:@selector(videoPlayerIsReadyToPlayVideo:)])
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate videoPlayerIsReadyToPlayVideo:self];
                        });
                    }
                    
                    if (self.isPlaying)
                    {
                        [self play];
                    }
                    
                    break;
                }
                case AVPlayerItemStatusFailed:
                {
                    NSLog(@"Video player Status Failed: player item error = %@", self.player.currentItem.error);
                    NSLog(@"Video player Status Failed: player error = %@", self.player.error);
                    
                    NSError *error = self.player.error;
                    if (!error)
                    {
                        error = self.player.currentItem.error;
                    }
                    else
                    {
                        error = [NSError errorWithDomain:kVideoPlayerErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"unknown player error, status == AVPlayerItemStatusFailed"}];
                    }
                    
                    [self reset];
                    
                    if ([self.delegate respondsToSelector:@selector(videoPlayer:didFailWithError:)])
                    {
                        _recevieVideoImageData = NO;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate videoPlayer:self didFailWithError:error];
                        });
                    }
                    
                    break;
                }
            }
        }
        else if (newStatus == AVPlayerItemStatusReadyToPlay)
        {
            // When playback resumes after a buffering event, a new ReadyToPlay status is set [RH]
            
            if ([self.delegate respondsToSelector:@selector(videoPlayerIsReadyToPlayVideo:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^
                               {
                                   [self.delegate videoPlayerIsReadyToPlayVideo:self];
                               });
            }
        }
    }
    else if (context == VideoPlayer_PlayerItemPlaybackBufferEmpty)
    {
        if (self.player.currentItem.playbackBufferEmpty)
        {
//            NSLog(@"no");

            if (self.isPlaying)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                               {
                                   if ([self.delegate respondsToSelector:@selector(videoPlayerPlaybackBufferEmpty:)])
                                   {
                                       [self.delegate videoPlayerPlaybackBufferEmpty:self];
                                   }
                               });
            }
        }
    }
    else if (context == VideoPlayer_PlayerItemPlaybackLikelyToKeepUp)
    {
        if (self.player.currentItem.playbackLikelyToKeepUp)
        {
            // TODO: Hide loading indicator
//            NSLog(@"has");

            if (self.isScrubbing == NO && self.isPlaying && self.player.rate)
            {                
                if ([self.delegate respondsToSelector:@selector(videoPlayerPlaybackLikelyToKeepUp:)])
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                                   {
                                       [self.delegate videoPlayerPlaybackLikelyToKeepUp:self];
                                   });
                }
            }
        }
    }
    else if (context == VideoPlayer_PlayerItemLoadedTimeRangesContext)
    {
        float loadedDuration = [self calcLoadedDuration];
        
        if (self.isScrubbing == NO && self.isPlaying && self.player.rate == 0.0f)
        {
            if (loadedDuration >= CMTimeGetSeconds(self.player.currentTime) + self.playableBufferLength)
            {
                self.playableBufferLength *= 2;
                
                if (self.playableBufferLength > 64)
                {
                    self.playableBufferLength = 64;
                }
                
                [self play];
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(videoPlayer:loadedTimeRangeDidChange:)])
        {
            [self.delegate videoPlayer:self loadedTimeRangeDidChange:loadedDuration];
        }
    }
    else if (context == VideoPlayer_PlayerExternalPlaybackActiveContext)
    {
        
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification
{
    if (notification.object != self.player.currentItem)
    {
        return;
    }
    
    if (self.isLooping)
    {
        [self restart];
    }
    else
    {
        _isAtEndTime = YES;
        self.playing = NO;
    }
    
    _recevieVideoImageData = NO;
    
    if ([self.delegate respondsToSelector:@selector(videoPlayerDidReachEnd:)])
    {
        [self.delegate videoPlayerDidReachEnd:self];
    }
}

#pragma mark - getter
- (CGFloat)duration
{
    if (!_duration)
    {
        _duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
    }
    
    return _duration;
}

- (CGFloat)currentTime
{
    _currentTime = CMTimeGetSeconds(self.player.currentTime);
    
    return _currentTime;
}
@end
