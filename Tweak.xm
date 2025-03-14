#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 引入 substrate 庫用於方法鉤子
#import "substrate.h"

// 設定偏好鍵名稱
static NSString *const kSpeedAdsEnabledKey = @"com.little34306.jailedspeedads.enabled";

// 控制按鈕類定義
@interface SpeedAdsControlButton : UIButton
@end

@implementation SpeedAdsControlButton {
    BOOL _isEnabled;
}

// 檢查偏好設置中是否啟用廣告加速
static BOOL isSpeedAdsEnabled() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kSpeedAdsEnabledKey] == nil) {
        return YES; // 默認啟用
    }
    return [defaults boolForKey:kSpeedAdsEnabledKey];
}

// 設置廣告加速狀態
static void setSpeedAdsEnabled(BOOL enabled) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kSpeedAdsEnabledKey];
    [defaults synchronize];
}

// 初始化控制按鈕
- (instancetype)init {
    if (self = [super init]) {
        _isEnabled = isSpeedAdsEnabled();
        
        // 設置按鈕外觀
        self.frame = CGRectMake(20, 120, 110, 44);
        self.layer.cornerRadius = 22;
        self.backgroundColor = _isEnabled ? 
            [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.8] : 
            [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.8];
        [self setTitle:_isEnabled ? @"廣告加速: 開" : @"廣告加速: 關" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        
        // 添加陰影提高可見度
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowRadius = 4;
        self.layer.shadowOpacity = 0.5;
        
        // 添加點擊事件
        [self addTarget:self action:@selector(toggleState) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖動手勢
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                                             initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];
    }
    return self;
}

// 切換按鈕狀態
- (void)toggleState {
    _isEnabled = !_isEnabled;
    setSpeedAdsEnabled(_isEnabled);
    
    // 更新按鈕外觀
    self.backgroundColor = _isEnabled ? 
        [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.8] : 
        [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.8];
    [self setTitle:_isEnabled ? @"廣告加速: 開" : @"廣告加速: 關" forState:UIControlStateNormal];
    
    // 顯示狀態變更通知
    UIWindow *window = self.window;
    if (window) {
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback prepare];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
        label.center = CGPointMake(window.frame.size.width / 2, window.frame.size.height / 2);
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        label.text = _isEnabled ? @"廣告加速已開啟" : @"廣告加速已關閉";
        label.layer.cornerRadius = 10;
        label.layer.masksToBounds = YES;
        
        [window addSubview:label];
        
        // 動畫顯示和消失
        label.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            label.alpha = 1;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    label.alpha = 0;
                } completion:^(BOOL finished) {
                    [label removeFromSuperview];
                }];
            });
        }];
    }
}

// 處理拖動手勢
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    // 確保按鈕在屏幕範圍內
    if (gesture.state == UIGestureRecognizerStateEnded) {
        UIWindow *window = self.window;
        if (window) {
            CGFloat minX = self.frame.size.width/2 + 10;
            CGFloat minY = self.frame.size.height/2 + 20;
            CGFloat maxX = window.frame.size.width - minX;
            CGFloat maxY = window.frame.size.height - minY;
            
            CGPoint center = self.center;
            if (center.x < minX) center.x = minX;
            if (center.y < minY) center.y = minY;
            if (center.x > maxX) center.x = maxX;
            if (center.y > maxY) center.y = maxY;
            
            [UIView animateWithDuration:0.3 animations:^{
                self.center = center;
            }];
        }
    }
}
@end

// 原始方法指針聲明
static BOOL (*original_GADAdSource_invalidated)(id self, SEL _cmd);
static BOOL (*original_ALAdView_isReady)(id self, SEL _cmd);
static id (*original_AVPlayer_initWithURL)(id self, SEL _cmd, id url);
static id (*original_AVPlayerItem_initWithURL)(id self, SEL _cmd, id url);
static id (*original_AVPlayerItem_initWithAsset)(id self, SEL _cmd, id asset);
static void (*original_AVScrubber_setMinValue)(id self, SEL _cmd, float value);
static void (*original_AVScrubber_setMaxValue)(id self, SEL _cmd, float value);
static id (*original_UADSMetaData_set)(id self, SEL _cmd, id key, id value);

// 鉤子方法實現
static BOOL new_GADAdSource_invalidated(id self, SEL _cmd) {
    if (isSpeedAdsEnabled()) {
        return NO; // 啟用時，返回NO加速廣告
    } else {
        return original_GADAdSource_invalidated(self, _cmd); // 禁用時調用原始方法
    }
}

static BOOL new_ALAdView_isReady(id self, SEL _cmd) {
    if (isSpeedAdsEnabled()) {
        return YES; // 啟用時，強制廣告就緒
    } else {
        return original_ALAdView_isReady(self, _cmd); // 禁用時調用原始方法
    }
}

// AVPlayer相關鉤子方法 - 用於加速廣告視頻播放
static id new_AVPlayer_initWithURL(id self, SEL _cmd, id url) {
    id result = original_AVPlayer_initWithURL(self, _cmd, url);
    if (isSpeedAdsEnabled()) {
        if ([url isKindOfClass:objc_getClass("NSURL")]) {
            NSString *urlString = [url absoluteString];
            if ([urlString containsString:@"ad"] || [urlString containsString:@"ads"] || 
                [urlString containsString:@"advertisement"]) {
                [self setRate:10.0]; // 廣告播放速度設為10倍
            }
        }
    }
    return result;
}

static id new_AVPlayerItem_initWithURL(id self, SEL _cmd, id url) {
    id result = original_AVPlayerItem_initWithURL(self, _cmd, url);
    if (isSpeedAdsEnabled()) {
        if ([url isKindOfClass:objc_getClass("NSURL")]) {
            NSString *urlString = [url absoluteString];
            if ([urlString containsString:@"ad"] || [urlString containsString:@"ads"] || 
                [urlString containsString:@"advertisement"]) {
                // 設置廣告項目屬性以便加速
                [result setValue:@(YES) forKey:@"_canPlayFastForward"];
                [result setValue:@(10.0) forKey:@"_preferredForwardBufferDuration"];
                [result setValue:@(YES) forKey:@"_usesExternalPlaybackWhileExternalScreenIsActive"];
            }
        }
    }
    return result;
}

static id new_AVPlayerItem_initWithAsset(id self, SEL _cmd, id asset) {
    id result = original_AVPlayerItem_initWithAsset(self, _cmd, asset);
    if (isSpeedAdsEnabled()) {
        // 嘗試檢查資產是否為廣告
        if ([asset respondsToSelector:@selector(URL)]) {
            NSURL *url = [asset URL];
            NSString *urlString = [url absoluteString];
            if ([urlString containsString:@"ad"] || [urlString containsString:@"ads"] || 
                [urlString containsString:@"advertisement"]) {
                // 設置廣告項目屬性以便加速
                [result setValue:@(YES) forKey:@"_canPlayFastForward"];
                [result setValue:@(10.0) forKey:@"_preferredForwardBufferDuration"];
            }
        }
    }
    return result;
}

// AVScrubber相關鉤子 - 用於縮短廣告時間軸
static void new_AVScrubber_setMinValue(id self, SEL _cmd, float value) {
    if (isSpeedAdsEnabled()) {
        // 縮短廣告時間範圍
        original_AVScrubber_setMinValue(self, _cmd, value);
    } else {
        original_AVScrubber_setMinValue(self, _cmd, value);
    }
}

static void new_AVScrubber_setMaxValue(id self, SEL _cmd, float value) {
    if (isSpeedAdsEnabled()) {
        // 對於廣告，將最大值設為較小值縮短廣告時長
        if (value > 5.0 && value < 120.0) { // 假設這是普通廣告時長範圍
            original_AVScrubber_setMaxValue(self, _cmd, value / 10.0);
        } else {
            original_AVScrubber_setMaxValue(self, _cmd, value);
        }
    } else {
        original_AVScrubber_setMaxValue(self, _cmd, value);
    }
}

// Unity廣告相關鉤子
static id new_UADSMetaData_set(id self, SEL _cmd, id key, id value) {
    if (isSpeedAdsEnabled() && [key isKindOfClass:objc_getClass("NSString")]) {
        NSString *keyString = (NSString *)key;
        if ([keyString isEqualToString:@"duration"] || [keyString containsString:@"time"]) {
            // 縮短Unity廣告顯示時間
            if ([value isKindOfClass:objc_getClass("NSNumber")]) {
                value = @([value floatValue] / 10.0);
            }
        }
    }
    return original_UADSMetaData_set(self, _cmd, key, value);
}

// 鉤子安裝函數
static void setupHooks() {
    // 保存原始實現並安裝鉤子
    MSHookMessageEx(objc_getClass("GADAdSource"), 
                   @selector(invalidated), 
                   (IMP)new_GADAdSource_invalidated, 
                   (IMP *)&original_GADAdSource_invalidated);
    
    MSHookMessageEx(objc_getClass("ALAdView"), 
                   @selector(isReady), 
                   (IMP)new_ALAdView_isReady, 
                   (IMP *)&original_ALAdView_isReady);
    
    MSHookMessageEx(objc_getClass("AVPlayer"), 
                   @selector(initWithURL:), 
                   (IMP)new_AVPlayer_initWithURL, 
                   (IMP *)&original_AVPlayer_initWithURL);
    
    MSHookMessageEx(objc_getClass("AVPlayerItem"), 
                   @selector(initWithURL:), 
                   (IMP)new_AVPlayerItem_initWithURL, 
                   (IMP *)&original_AVPlayerItem_initWithURL);
    
    MSHookMessageEx(objc_getClass("AVPlayerItem"), 
                   @selector(initWithAsset:), 
                   (IMP)new_AVPlayerItem_initWithAsset, 
                   (IMP *)&original_AVPlayerItem_initWithAsset);
    
    MSHookMessageEx(objc_getClass("AVScrubber"), 
                   @selector(setMinValue:), 
                   (IMP)new_AVScrubber_setMinValue, 
                   (IMP *)&original_AVScrubber_setMinValue);
    
    MSHookMessageEx(objc_getClass("AVScrubber"), 
                   @selector(setMaxValue:), 
                   (IMP)new_AVScrubber_setMaxValue, 
                   (IMP *)&original_AVScrubber_setMaxValue);
    
    MSHookMessageEx(objc_getClass("UADSMetaData"), 
                   @selector(set:value:), 
                   (IMP)new_UADSMetaData_set, 
                   (IMP *)&original_UADSMetaData_set);
}

// 添加控制按鈕到界面
static void addControlButtonToUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if (keyWindow) {
            SpeedAdsControlButton *controlButton = [[SpeedAdsControlButton alloc] init];
            [keyWindow addSubview:controlButton];
            [keyWindow bringSubviewToFront:controlButton];
        }
    });
}

// Tweak入口點
%ctor {
    // 初始化鉤子
    setupHooks();
    
    // 添加控制按鈕（延遲執行以確保UI準備就緒）
    addControlButtonToUI();
    
    // 輸出調試信息
    NSLog(@"[JailedSpeedAds] Tweak initialized! Ad Speed Control enabled.");
}
