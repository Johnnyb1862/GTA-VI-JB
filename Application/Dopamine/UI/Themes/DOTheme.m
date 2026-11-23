//
//  DOTheme.m
//  Dopamine
//
//  Created by tomt000 on 14/02/2024.
//

#import "DOTheme.h"
#import "UIImage+Blur.h"
#import <math.h>

// GTA VI JB palette (Vice City sunset)
#define DO_COLOR_INK      [UIColor colorWithRed:0.043 green:0.024 blue:0.071 alpha:1.0]
#define DO_COLOR_PURPLE   [UIColor colorWithRed:0.231 green:0.039 blue:0.271 alpha:1.0]
#define DO_COLOR_MAGENTA  [UIColor colorWithRed:0.557 green:0.106 blue:0.357 alpha:1.0]
#define DO_COLOR_PINK     [UIColor colorWithRed:1.000 green:0.176 blue:0.541 alpha:1.0]
#define DO_COLOR_ORANGE   [UIColor colorWithRed:1.000 green:0.478 blue:0.145 alpha:1.0]
#define DO_COLOR_GOLD     [UIColor colorWithRed:1.000 green:0.749 blue:0.353 alpha:1.0]

// Canvas the generated theme artwork (and therefore the boot logo) is drawn on
#define DO_ARTWORK_SIZE CGSizeMake(1290, 2796)

@interface DOTheme ()
@property (nonatomic, retain) NSString *imageName;
@end

@implementation DOTheme

- (id)initWithDictionary: (NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        self.name = [dictionary objectForKey:@"name"];
        self.icon = [dictionary objectForKey:@"icon"];
        self.key = [dictionary objectForKey:@"key"];
        self.imageName = [dictionary objectForKey:@"image"];
        self.windowColor = [self colorFromHexString:[dictionary objectForKey:@"windowColor"]];
        self.actionMenuColor = [self colorFromHexString:[dictionary objectForKey:@"actionMenuColor"]];
        self.blur = [[dictionary objectForKey:@"blur"] floatValue];
        self.titleShadow = [[dictionary objectForKey:@"titleShadow"] boolValue];
    }
    return self;
}

- (UIColor*)colorFromHexString:(NSString*)hexString
{
    unsigned int hexInt = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&hexInt];
    return [UIColor colorWithRed:((CGFloat)((hexInt & 0xFF0000) >> 16))/255.0 green:((CGFloat)((hexInt & 0xFF00) >> 8))/255.0 blue:((CGFloat)(hexInt & 0xFF))/255.0 alpha:((CGFloat)((hexInt & 0xFF000000) >> 24))/255.0];
}

- (UIImage *)image
{
    if (_image == nil) {
        UIImage *image = self.imageName ? [UIImage imageNamed:self.imageName] : nil;

        // Themes without a bundled backdrop (GTA VI JB) get their artwork drawn at runtime
        if (!image) image = [self generatedBackgroundImage];

        if (self.blur > 0) image = [image imageWithBlur:self.blur];

        _image = image;
    }
    return _image;
}

#pragma mark - Generated artwork

- (UIImage *)generatedBackgroundImage
{
    CGSize size = DO_ARTWORK_SIZE;

    UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    [self drawSunsetInContext:ctx size:size];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (void)drawSunsetInContext:(CGContextRef)ctx size:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Dusk sky
    NSArray *skyColors = @[
        (id)[UIColor colorWithRed:0.055 green:0.027 blue:0.106 alpha:1.0].CGColor,
        (id)DO_COLOR_PURPLE.CGColor,
        (id)DO_COLOR_MAGENTA.CGColor,
        (id)[UIColor colorWithRed:0.878 green:0.271 blue:0.353 alpha:1.0].CGColor,
        (id)DO_COLOR_ORANGE.CGColor,
        (id)DO_COLOR_GOLD.CGColor,
    ];
    CGFloat skyLocations[] = {0.0, 0.20, 0.44, 0.63, 0.78, 0.88};

    CGGradientRef sky = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)skyColors, skyLocations);
    CGContextDrawLinearGradient(ctx, sky,
                                CGPointMake(0, 0),
                                CGPointMake(0, size.height),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(sky);

    // Sun glow
    CGPoint sunCenter = CGPointMake(size.width * 0.5, size.height * 0.63);
    CGFloat sunRadius = size.width * 0.62;

    NSArray *glowColors = @[
        (id)[UIColor colorWithRed:1.0 green:0.898 blue:0.686 alpha:0.55].CGColor,
        (id)[UIColor colorWithRed:1.0 green:0.478 blue:0.145 alpha:0.22].CGColor,
        (id)DO_COLOR_PINK.CGColor,
    ];
    CGFloat glowLocations[] = {0.0, 0.42, 1.0};

    CGGradientRef glow = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)glowColors, glowLocations);
    CGContextDrawRadialGradient(ctx, glow, sunCenter, 0, sunCenter, sunRadius, 0);
    CGGradientRelease(glow);

    CGColorSpaceRelease(colorSpace);

    // Sun disc
    CGFloat discRadius = size.width * 0.15;
    [DO_COLOR_GOLD setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(sunCenter.x - discRadius,
                                                       sunCenter.y - discRadius,
                                                       discRadius * 2,
                                                       discRadius * 2)] fill];

    // Retro horizontal bands across the sun
    [[UIColor colorWithRed:0.231 green:0.039 blue:0.271 alpha:0.45] setFill];
    for (int i = 0; i < 5; i++) {
        CGFloat bandHeight = discRadius * (0.06 + i * 0.03);
        CGFloat bandY = sunCenter.y + discRadius * 0.10 + i * discRadius * 0.30;
        [[UIBezierPath bezierPathWithRect:CGRectMake(sunCenter.x - discRadius,
                                                     bandY,
                                                     discRadius * 2,
                                                     bandHeight)] fill];
    }

    // City skyline
    CGFloat groundY = size.height * 0.90;
    UIBezierPath *skyline = [UIBezierPath bezierPath];
    [skyline moveToPoint:CGPointMake(0, size.height)];
    [skyline addLineToPoint:CGPointMake(0, groundY)];
    CGFloat cityX = 0;
    int building = 0;
    while (cityX < size.width) {
        CGFloat buildingWidth = size.width * (0.025 + ((building * 7) % 5) * 0.011);
        CGFloat buildingHeight = size.height * (0.010 + ((building * 3) % 7) * 0.007);
        [skyline addLineToPoint:CGPointMake(cityX, groundY - buildingHeight)];
        [skyline addLineToPoint:CGPointMake(cityX + buildingWidth, groundY - buildingHeight)];
        cityX += buildingWidth;
        building++;
    }
    [skyline addLineToPoint:CGPointMake(size.width, size.height)];
    [skyline closePath];
    [DO_COLOR_INK setFill];
    [skyline fill];

    // Palms in the foreground
    [self drawPalmInContext:ctx
                       base:CGPointMake(size.width * 0.13, groundY + size.height * 0.03)
                     height:size.height * 0.21
                       lean:size.width * 0.035];
    [self drawPalmInContext:ctx
                       base:CGPointMake(size.width * 0.87, groundY + size.height * 0.04)
                     height:size.height * 0.16
                       lean:-size.width * 0.030];
}

- (void)drawPalmInContext:(CGContextRef)ctx base:(CGPoint)base height:(CGFloat)height lean:(CGFloat)lean
{
    [DO_COLOR_INK setStroke];

    CGPoint top = CGPointMake(base.x + lean, base.y - height);

    UIBezierPath *trunk = [UIBezierPath bezierPath];
    [trunk moveToPoint:base];
    [trunk addQuadCurveToPoint:top
                 controlPoint:CGPointMake(base.x + lean * 0.15, base.y - height * 0.55)];
    trunk.lineWidth = height * 0.035;
    trunk.lineCapStyle = kCGLineCapRound;
    [trunk stroke];

    for (int i = 0; i < 7; i++) {
        CGFloat angle = (-M_PI * 0.94) + (M_PI * 0.88) * ((CGFloat)i / 6.0);
        CGFloat frondLength = height * (0.42 + ((i % 3) * 0.07));

        UIBezierPath *frond = [UIBezierPath bezierPath];
        [frond moveToPoint:top];
        [frond addQuadCurveToPoint:CGPointMake(top.x + cos(angle) * frondLength,
                                               top.y + sin(angle) * frondLength * 0.55)
                     controlPoint:CGPointMake(top.x + cos(angle) * frondLength * 0.55,
                                              top.y + sin(angle) * frondLength * 0.95)];
        frond.lineWidth = height * 0.022;
        frond.lineCapStyle = kCGLineCapRound;
        [frond stroke];
    }
}

#pragma mark - Boot logo (userspace reboot splash)

- (UIImage *)generateBootLogo
{
    UIImage *backgroundImage = [self image];
    if (!backgroundImage) return nil;

    CGSize canvasSize = backgroundImage.size;

    UIGraphicsBeginImageContextWithOptions(canvasSize, YES, backgroundImage.scale);

    [backgroundImage drawInRect:CGRectMake(0, 0, canvasSize.width, canvasSize.height)];

    // Scrim so the lockup stays readable over a photographic backdrop
    [[UIColor colorWithWhite:0.0 alpha:0.38] setFill];
    [[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, canvasSize.width, canvasSize.height)] fill];

    [self drawVignetteInContext:UIGraphicsGetCurrentContext() size:canvasSize];
    [self drawSkyMontageInContext:UIGraphicsGetCurrentContext() size:canvasSize];
    [self drawSplashLockupInContext:UIGraphicsGetCurrentContext() size:canvasSize];

    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return finalImage;
}

- (void)drawVignetteInContext:(CGContextRef)ctx size:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    NSArray *colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.62].CGColor,
    ];
    CGFloat locations[] = {0.0, 1.0};

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGPoint center = CGPointMake(size.width / 2.0, size.height / 2.0);
    CGContextDrawRadialGradient(ctx, gradient, center, 0, center,
                                MAX(size.width, size.height) * 0.78,
                                kCGGradientDrawsAfterEndLocation);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

- (void)drawSplashLockupInContext:(CGContextRef)ctx size:(CGSize)size
{
    CGFloat width = size.width;
    CGFloat height = size.height;

    NSMutableParagraphStyle *centered = [[NSMutableParagraphStyle alloc] init];
    centered.alignment = NSTextAlignmentCenter;

    NSShadow *romanShadow = [[NSShadow alloc] init];
    romanShadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    romanShadow.shadowBlurRadius = width * 0.02;
    romanShadow.shadowOffset = CGSizeMake(0, width * 0.006);

    NSString *kicker = @"GRAND THEFT AUTO";
    NSString *roman = @"VI";
    NSString *title = @"GTA VI JB";
    NSString *tagline = @"JAILBREAK";

    NSDictionary *kickerAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:width * 0.030 weight:UIFontWeightHeavy],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.88],
        NSKernAttributeName: @(width * 0.0075),
        NSParagraphStyleAttributeName: centered,
    };
    NSDictionary *romanAttributes = @{
        NSFontAttributeName: [DOTheme italicFontOfSize:width * 0.300 weight:UIFontWeightBlack],
        NSForegroundColorAttributeName: DO_COLOR_ORANGE,
        NSStrokeColorAttributeName: [UIColor colorWithWhite:0.0 alpha:0.35],
        NSStrokeWidthAttributeName: @(-2.5),
        NSShadowAttributeName: romanShadow,
        NSParagraphStyleAttributeName: centered,
    };
    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [DOTheme italicFontOfSize:width * 0.062 weight:UIFontWeightBlack],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSKernAttributeName: @(width * 0.002),
        NSParagraphStyleAttributeName: centered,
    };
    NSDictionary *taglineAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:width * 0.024 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: DO_COLOR_PINK,
        NSKernAttributeName: @(width * 0.012),
        NSParagraphStyleAttributeName: centered,
    };

    CGSize kickerSize = [kicker sizeWithAttributes:kickerAttributes];
    CGSize romanSize = [roman sizeWithAttributes:romanAttributes];
    CGSize titleSize = [title sizeWithAttributes:titleAttributes];
    CGSize taglineSize = [tagline sizeWithAttributes:taglineAttributes];

    CGFloat ruleHeight = width * 0.0035;
    CGFloat gapKicker = height * 0.012;
    CGFloat gapRule = height * 0.018;

    CGFloat totalHeight = kickerSize.height + gapKicker + romanSize.height + gapRule +
                          ruleHeight + gapRule + titleSize.height + height * 0.010 +
                          taglineSize.height;

    CGFloat y = (height - totalHeight) / 2.0 - height * 0.02;

    [kicker drawInRect:CGRectMake(0, y, width, kickerSize.height + 8) withAttributes:kickerAttributes];
    y += kickerSize.height + gapKicker;

    [roman drawInRect:CGRectMake(0, y, width, romanSize.height + 8) withAttributes:romanAttributes];
    y += romanSize.height + gapRule;

    CGFloat ruleWidth = width * 0.34;
    [[UIColor colorWithRed:1.0 green:0.176 blue:0.541 alpha:0.25] setFill];
    [[UIBezierPath bezierPathWithRect:CGRectMake((width - ruleWidth) / 2.0 - 6,
                                                 y - 3,
                                                 ruleWidth + 12,
                                                 ruleHeight + 6)] fill];
    [DO_COLOR_PINK setFill];
    [[UIBezierPath bezierPathWithRect:CGRectMake((width - ruleWidth) / 2.0,
                                                 y,
                                                 ruleWidth,
                                                 ruleHeight)] fill];
    y += ruleHeight + gapRule;

    [title drawInRect:CGRectMake(0, y, width, titleSize.height + 8) withAttributes:titleAttributes];
    y += titleSize.height + height * 0.010;

    [tagline drawInRect:CGRectMake(0, y, width, taglineSize.height + 8) withAttributes:taglineAttributes];
}

#pragma mark - Sky montage

// A distant street of cars and pedestrians, silhouetted in the open sky above the palm.
// Everything here is drawn from vector paths, so no third-party artwork ships in the app.
- (void)drawSkyMontageInContext:(CGContextRef)ctx size:(CGSize)size
{
    CGFloat width = size.width;
    CGFloat height = size.height;
    CGFloat horizon = height * 0.215;
    CGFloat unit = height * 0.010;

    UIColor *ink = [UIColor colorWithWhite:0.02 alpha:0.70];
    [ink setFill];
    [ink setStroke];

    // The road they stand on
    [[UIBezierPath bezierPathWithRect:CGRectMake(0, horizon, width, MAX(1.0, height * 0.0013))] fill];

    CGFloat carPositions[] = {0.09, 0.36, 0.72};
    for (int i = 0; i < 3; i++) {
        [self drawSilhouetteCarInContext:ctx
                                     atX:width * carPositions[i]
                                 groundY:horizon
                                   scale:unit * (i == 1 ? 1.05 : 0.82)];
    }

    CGFloat peoplePositions[] = {0.19, 0.24, 0.29, 0.50, 0.55, 0.62, 0.86, 0.91};
    for (int i = 0; i < 8; i++) {
        [self drawSilhouettePersonInContext:ctx
                                        atX:width * peoplePositions[i]
                                    groundY:horizon
                                      scale:unit * (1.45 + ((i % 3) * 0.12))
                                     stride:(CGFloat)i * 0.9];
    }
}

- (void)drawSilhouetteCarInContext:(CGContextRef)ctx atX:(CGFloat)x groundY:(CGFloat)groundY scale:(CGFloat)s
{
    CGFloat bodyWidth = s * 6.4;
    CGFloat bodyHeight = s * 1.9;
    CGFloat wheelRadius = s * 0.85;

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, x, groundY);

    for (CGFloat sign = -1.0; sign <= 1.0; sign += 2.0) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(sign * bodyWidth * 0.30 - wheelRadius,
                                                           -wheelRadius * 1.7,
                                                           wheelRadius * 2.0,
                                                           wheelRadius * 2.0)] fill];
    }

    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(-bodyWidth * 0.5,
                                                        -bodyHeight - wheelRadius * 0.9,
                                                        bodyWidth,
                                                        bodyHeight)
                                 cornerRadius:bodyHeight * 0.25] fill];

    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(-bodyWidth * 0.22,
                                                        -bodyHeight * 1.85 - wheelRadius * 0.9,
                                                        bodyWidth * 0.52,
                                                        bodyHeight * 0.95)
                                 cornerRadius:bodyHeight * 0.22] fill];

    CGContextRestoreGState(ctx);
}

- (void)drawSilhouettePersonInContext:(CGContextRef)ctx atX:(CGFloat)x groundY:(CGFloat)groundY scale:(CGFloat)s stride:(CGFloat)stride
{
    CGFloat tall = s * 2.6;
    CGFloat swing = sin(stride) * s * 0.35;

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, x, groundY);

    // Head
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-s * 0.22, -tall, s * 0.44, s * 0.44)] fill];

    UIBezierPath *figure = [UIBezierPath bezierPath];
    figure.lineWidth = MAX(1.0, s * 0.30);
    figure.lineCapStyle = kCGLineCapRound;

    [figure moveToPoint:CGPointMake(0, -tall + s * 0.44)];
    [figure addLineToPoint:CGPointMake(0, -tall * 0.42)];

    [figure moveToPoint:CGPointMake(0, -tall * 0.78)];
    [figure addLineToPoint:CGPointMake(-s * 0.50, -tall * 0.55 + swing)];
    [figure moveToPoint:CGPointMake(0, -tall * 0.78)];
    [figure addLineToPoint:CGPointMake(s * 0.50, -tall * 0.55 - swing)];

    [figure moveToPoint:CGPointMake(0, -tall * 0.42)];
    [figure addLineToPoint:CGPointMake(swing, 0)];
    [figure moveToPoint:CGPointMake(0, -tall * 0.42)];
    [figure addLineToPoint:CGPointMake(-swing, 0)];

    [figure stroke];

    CGContextRestoreGState(ctx);
}

#pragma mark - Wordmark

+ (UIImage *)brandWordmarkImage
{
    CGSize size = CGSizeMake(240, 80);

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);

    NSMutableParagraphStyle *left = [[NSMutableParagraphStyle alloc] init];
    left.alignment = NSTextAlignmentLeft;

    NSDictionary *gtaAttributes = @{
        NSFontAttributeName: [DOTheme italicFontOfSize:50 weight:UIFontWeightBlack],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSKernAttributeName: @(-1.5),
        NSParagraphStyleAttributeName: left,
    };
    NSDictionary *viAttributes = @{
        NSFontAttributeName: [DOTheme italicFontOfSize:58 weight:UIFontWeightBlack],
        NSForegroundColorAttributeName: DO_COLOR_ORANGE,
        NSStrokeColorAttributeName: [UIColor colorWithWhite:0.0 alpha:0.45],
        NSStrokeWidthAttributeName: @(-2.0),
        NSParagraphStyleAttributeName: left,
    };

    CGSize gtaSize = [@"GTA" sizeWithAttributes:gtaAttributes];
    [@"GTA" drawInRect:CGRectMake(0, 14, gtaSize.width + 6, gtaSize.height + 8) withAttributes:gtaAttributes];

    CGFloat viX = gtaSize.width - 2;
    CGSize viSize = [@"VI" sizeWithAttributes:viAttributes];
    [@"VI" drawInRect:CGRectMake(viX, 6, viSize.width + 6, viSize.height + 8) withAttributes:viAttributes];

    UIFont *badgeFont = [UIFont systemFontOfSize:19 weight:UIFontWeightBlack];
    NSDictionary *badgeAttributes = @{
        NSFontAttributeName: badgeFont,
        NSForegroundColorAttributeName: [UIColor whiteColor],
    };
    CGSize badgeTextSize = [@"JB" sizeWithAttributes:badgeAttributes];
    CGRect badgeRect = CGRectMake(viX + viSize.width, 28, badgeTextSize.width + 12, badgeTextSize.height + 6);

    [DO_COLOR_PINK setFill];
    [[UIBezierPath bezierPathWithRoundedRect:badgeRect cornerRadius:6] fill];
    [@"JB" drawAtPoint:CGPointMake(badgeRect.origin.x + 6, badgeRect.origin.y + 3) withAttributes:badgeAttributes];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

+ (UIFont *)italicFontOfSize:(CGFloat)size weight:(UIFontWeight)weight
{
    UIFont *baseFont = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *italicDescriptor = [baseFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    UIFont *italicFont = italicDescriptor ? [UIFont fontWithDescriptor:italicDescriptor size:size] : nil;
    return italicFont ?: baseFont;
}

@end
