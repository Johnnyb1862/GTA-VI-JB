//
//  AppDelegate.m
//  Dopamine
//
//  Created by Lars Fröder on 23.09.23.
//

#import "DOAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

#define DO_AUDIO_SAMPLE_RATE 22050.0
#define DO_AUDIO_BARS 4
#define DO_AUDIO_BAR_SECONDS 3.0

static AVAudioPlayer *gGTAThemePlayer;

static void DOAppendUInt16LE(NSMutableData *data, uint16_t value)
{
    uint8_t bytes[2] = { (uint8_t)(value & 0xFF), (uint8_t)((value >> 8) & 0xFF) };
    [data appendBytes:bytes length:2];
}

static void DOAppendUInt32LE(NSMutableData *data, uint32_t value)
{
    uint8_t bytes[4] = {
        (uint8_t)(value & 0xFF),
        (uint8_t)((value >> 8) & 0xFF),
        (uint8_t)((value >> 16) & 0xFF),
        (uint8_t)((value >> 24) & 0xFF),
    };
    [data appendBytes:bytes length:4];
}

// Synthesises a looping synthwave vamp (A minor, 4 bars of bass, arpeggio and kick) and writes it
// as 16-bit mono PCM. Generated rather than shipped so no third-party music is redistributed.
static void DOWriteThemeLoop(NSString *path)
{
    const double sampleRate = DO_AUDIO_SAMPLE_RATE;
    const double totalSeconds = DO_AUDIO_BAR_SECONDS * DO_AUDIO_BARS;
    const int sampleCount = (int)(sampleRate * totalSeconds);

    static const double chordRoots[4] = {220.00, 174.61, 261.63, 196.00}; // A3, F3, C4, G3
    static const double arpRatios[4] = {2.0, 2.4, 3.0, 4.0};

    NSMutableData *pcm = [NSMutableData dataWithCapacity:(NSUInteger)sampleCount * 2];

    for (int i = 0; i < sampleCount; i++) {
        double t = (double)i / sampleRate;
        int bar = (int)(t / DO_AUDIO_BAR_SECONDS) % DO_AUDIO_BARS;
        double barTime = fmod(t, DO_AUDIO_BAR_SECONDS);
        double root = chordRoots[bar];

        double bassEnvelope = exp(-2.2 * barTime);
        double bass = sin(2.0 * M_PI * (root / 2.0) * t) * bassEnvelope * 0.42;

        double stepLength = DO_AUDIO_BAR_SECONDS / 8.0;
        int step = (int)(barTime / stepLength);
        double stepTime = fmod(barTime, stepLength);
        double arpEnvelope = exp(-9.0 * stepTime);
        double arpFrequency = root * arpRatios[step % 4] * 2.0;
        double arp = sin(2.0 * M_PI * arpFrequency * t) * arpEnvelope * 0.17;

        double kickTime = fmod(t, 0.75);
        double kick = sin(2.0 * M_PI * 55.0 * (1.0 + 2.5 * exp(-30.0 * kickTime)) * t) * exp(-14.0 * kickTime) * 0.30;

        double sample = bass + arp + kick;

        // Short fades at the loop boundary so the end and start meet without a click
        double edge = MIN(1.0, MIN(t / 0.02, (totalSeconds - t) / 0.02));
        sample *= MAX(0.0, edge);

        if (sample > 0.95) sample = 0.95;
        if (sample < -0.95) sample = -0.95;

        uint16_t out = (uint16_t)(int16_t)lrint(sample * 32767.0);
        uint8_t bytes[2] = { (uint8_t)(out & 0xFF), (uint8_t)((out >> 8) & 0xFF) };
        [pcm appendBytes:bytes length:2];
    }

    NSMutableData *file = [NSMutableData data];
    uint32_t dataSize = (uint32_t)pcm.length;

    [file appendData:[@"RIFF" dataUsingEncoding:NSUTF8StringEncoding]];
    DOAppendUInt32LE(file, 36 + dataSize);
    [file appendData:[@"WAVEfmt " dataUsingEncoding:NSUTF8StringEncoding]];
    DOAppendUInt32LE(file, 16);                       // fmt chunk size
    DOAppendUInt16LE(file, 1);                        // PCM
    DOAppendUInt16LE(file, 1);                        // mono
    DOAppendUInt32LE(file, (uint32_t)sampleRate);
    DOAppendUInt32LE(file, (uint32_t)sampleRate * 2); // byte rate
    DOAppendUInt16LE(file, 2);                        // block align
    DOAppendUInt16LE(file, 16);                       // bits per sample
    [file appendData:[@"data" dataUsingEncoding:NSUTF8StringEncoding]];
    DOAppendUInt32LE(file, dataSize);
    [file appendData:pcm];

    [file writeToFile:path atomically:YES];
}

@interface DOAppDelegate ()

- (void)startThemeAudio;

@end

@implementation DOAppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self startThemeAudio];
    return YES;
}

- (void)startThemeAudio
{
    @try {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"gtavi_theme_loop.wav"];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        if (![fileManager fileExistsAtPath:path]) {
            DOWriteThemeLoop(path);
        }
        if (![fileManager fileExistsAtPath:path]) return;

        // Ambient obeys the ring/silent switch and mixes with anything else playing
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryAmbient error:nil];
        [session setActive:YES error:nil];

        gGTAThemePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        if (!gGTAThemePlayer) return;

        gGTAThemePlayer.numberOfLoops = -1;
        gGTAThemePlayer.volume = 0.35f;
        [gGTAThemePlayer play];
    } @catch (NSException *exception) {
        NSLog(@"GTA VI JB: theme audio unavailable: %@", exception);
    }
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAll;
    return UIInterfaceOrientationMaskPortrait;
}

@end
