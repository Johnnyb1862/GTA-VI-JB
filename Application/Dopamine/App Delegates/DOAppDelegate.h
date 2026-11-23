//
//  AppDelegate.h
//  Dopamine
//
//  Created by Lars Fröder on 23.09.23.
//

#import <UIKit/UIKit.h>

@interface DOAppDelegate : UIResponder <UIApplicationDelegate>

// Fades the theme music out; called just before the userspace reboot
+ (void)fadeOutThemeAudio;

@end

