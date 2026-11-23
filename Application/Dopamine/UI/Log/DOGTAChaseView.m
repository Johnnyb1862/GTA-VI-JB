//
//  DOGTAChaseView.m
//  Dopamine
//
//  Replaces the scrolling log with a GTA-style chase scene. Everything is drawn with
//  Core Graphics so it needs no artwork: a scrolling street, a police car with flashing
//  lights, pedestrians that get knocked flying, and a six-star wanted meter.
//
//  The scene is decorative; the star count is driven by the jailbreak's log events so it
//  reflects real progress. The sixth star only lights up on completion, which is when
//  WASTED appears.
//

#import "DOGTAChaseView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#define DO_MAX_PEDESTRIANS 8
#define DO_MAX_STARS 6
// Stars earned from log events; the sixth is reserved for completion
#define DO_MAX_PROGRESS_STARS 5
#define DO_LOGS_PER_STAR 2
#define DO_CAR_SPEED 240.0

typedef struct {
    CGFloat worldX;
    CGFloat yOffset;    // height above the road surface, 0 = standing
    CGFloat velocityX;
    CGFloat velocityY;
    CGFloat walkPhase;
    BOOL knocked;
} DOPedestrian;

@interface DOGTAChaseView ()
{
    DOPedestrian _pedestrians[DO_MAX_PEDESTRIANS];
}

@property (nonatomic, strong, nullable) CADisplayLink *displayLink;
@property (nonatomic) CFTimeInterval lastTimestamp;
@property (nonatomic) CGFloat time;
@property (nonatomic) CGFloat worldOffset;
@property (nonatomic) NSInteger wantedLevel;
@property (nonatomic) NSInteger logCount;
@property (nonatomic) BOOL completed;

@end

@implementation DOGTAChaseView

- (instancetype)init
{
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
        [self resetPedestrians];
    }
    return self;
}

- (void)resetPedestrians
{
    for (NSInteger i = 0; i < DO_MAX_PEDESTRIANS; i++) {
        _pedestrians[i].worldX = i * 260.0;
        _pedestrians[i].yOffset = 0;
        _pedestrians[i].velocityX = 0;
        _pedestrians[i].velocityY = 0;
        _pedestrians[i].walkPhase = (CGFloat)i * 0.7;
        _pedestrians[i].knocked = NO;
    }
}

#pragma mark - Display link

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)startAnimating
{
    if (self.displayLink) return;
    self.lastTimestamp = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating
{
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)step:(CADisplayLink *)link
{
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }
    CGFloat dt = (CGFloat)(link.timestamp - self.lastTimestamp);
    self.lastTimestamp = link.timestamp;
    // Clamp so a stall (or the app coming back to the foreground) does not teleport the scene
    dt = MIN(dt, 0.05);
    self.time += dt;
    [self advanceWithDelta:dt];
    [self setNeedsDisplay];
}

- (void)advanceWithDelta:(CGFloat)dt
{
    CGSize size = self.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;

    self.worldOffset += DO_CAR_SPEED * dt;

    CGFloat carX = size.width * 0.30;
    CGFloat roadY = size.height * 0.72;

    for (NSInteger i = 0; i < DO_MAX_PEDESTRIANS; i++) {
        DOPedestrian *pedestrian = &_pedestrians[i];
        CGFloat screenX = pedestrian->worldX - self.worldOffset;

        if (pedestrian->knocked) {
            pedestrian->velocityY -= 1500.0 * dt;
            pedestrian->yOffset += pedestrian->velocityY * dt;
            pedestrian->worldX += pedestrian->velocityX * dt;

            // Gone below the road and well off screen: send them round again
            if (pedestrian->yOffset < -roadY) {
                pedestrian->knocked = NO;
                pedestrian->yOffset = 0;
                pedestrian->velocityX = 0;
                pedestrian->velocityY = 0;
                pedestrian->worldX = self.worldOffset + size.width + 120.0 + (CGFloat)(i * 40);
            }
            continue;
        }

        pedestrian->walkPhase += dt * 6.0;

        // Run them over when the front of the car reaches them
        if (screenX < carX + 40.0 && screenX > carX - 120.0) {
            pedestrian->knocked = YES;
            pedestrian->velocityY = 430.0;
            pedestrian->velocityX = -160.0;
        } else if (screenX < -100.0) {
            pedestrian->worldX = self.worldOffset + size.width + 60.0 + (CGFloat)((i * 53) % 300);
        }
    }
}

#pragma mark - Progress

- (void)showLog:(NSString *)log
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLog:log];
        });
        return;
    }

    self.logCount++;
    NSInteger level = MIN(DO_MAX_PROGRESS_STARS, self.logCount / DO_LOGS_PER_STAR);
    if (level > self.wantedLevel) {
        self.wantedLevel = level;
        [self starEarned];
    }
    [self setNeedsDisplay];
}

- (void)updateLog:(NSString *)log
{
    // Intermediate progress updates carry no extra meaning for the chase
}

- (void)didComplete
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self didComplete];
        });
        return;
    }

    self.completed = YES;
    self.wantedLevel = DO_MAX_STARS;
    [self starEarned];
    [self setNeedsDisplay];
}

- (void)starEarned
{
    if (self.window) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGSize size = self.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;

    CGFloat roadY = size.height * 0.72;

    [self drawSkylineInContext:ctx size:size roadY:roadY];
    [self drawRoadInContext:ctx size:size roadY:roadY];

    for (NSInteger i = 0; i < DO_MAX_PEDESTRIANS; i++) {
        DOPedestrian *pedestrian = &_pedestrians[i];
        CGFloat screenX = pedestrian->worldX - self.worldOffset;
        if (screenX < -80.0 || screenX > size.width + 80.0) continue;

        CGFloat rotation = pedestrian->knocked ? (self.time * 3.0 + (CGFloat)i) : 0.0;
        [self drawPedestrianInContext:ctx
                                  atX:screenX
                                groundY:roadY
                             yOffset:pedestrian->yOffset
                             rotation:rotation
                            walkPhase:pedestrian->walkPhase
                              knocked:pedestrian->knocked];
    }

    [self drawCarInContext:ctx size:size roadY:roadY carX:size.width * 0.30];
    [self drawWantedStarsInContext:ctx size:size];

    if (self.completed) {
        [self drawWastedInContext:ctx size:size];
    }
}

- (void)drawSkylineInContext:(CGContextRef)ctx size:(CGSize)size roadY:(CGFloat)roadY
{
    // Slow parallax so the city drifts behind the street
    CGFloat parallax = self.worldOffset * 0.25;
    CGFloat buildingWidth = 74.0;

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.06 alpha:0.92].CGColor);

    NSInteger count = (NSInteger)(size.width / buildingWidth) + 2;
    for (NSInteger i = 0; i < count; i++) {
        CGFloat x = (CGFloat)i * buildingWidth - fmod(parallax, buildingWidth);
        NSInteger seed = (NSInteger)((x + parallax) / buildingWidth);
        CGFloat height = roadY * (0.16 + (CGFloat)((seed * 37) % 10) * 0.035);
        CGContextFillRect(ctx, CGRectMake(x, roadY - height, buildingWidth - 6.0, height));

        // Lit windows
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.78 blue:0.35 alpha:0.20].CGColor);
        NSInteger windows = (NSInteger)(height / 22.0);
        for (NSInteger w = 0; w < windows; w++) {
            if (((seed + w) % 3) == 0) continue;
            CGContextFillRect(ctx, CGRectMake(x + 10.0, roadY - height + 10.0 + (CGFloat)w * 22.0, 12.0, 9.0));
        }
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.06 alpha:0.92].CGColor);
    }
}

- (void)drawRoadInContext:(CGContextRef)ctx size:(CGSize)size roadY:(CGFloat)roadY
{
    // Asphalt
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.09 alpha:0.96].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, roadY, size.width, size.height - roadY));

    // Kerb
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.32 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, roadY, size.width, 3.0));

    // Lane markings scrolling past, to sell the speed
    CGFloat dashWidth = 54.0;
    CGFloat gap = 42.0;
    CGFloat period = dashWidth + gap;
    CGFloat offset = fmod(self.worldOffset, period);

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.85 alpha:0.35].CGColor);
    for (CGFloat x = -offset; x < size.width; x += period) {
        CGContextFillRect(ctx, CGRectMake(x, roadY + (size.height - roadY) * 0.55, dashWidth, 5.0));
    }
}

- (void)drawCarInContext:(CGContextRef)ctx size:(CGSize)size roadY:(CGFloat)roadY carX:(CGFloat)carX
{
    CGFloat bodyWidth = MIN(150.0, size.width * 0.42);
    CGFloat bodyHeight = bodyWidth * 0.30;
    CGFloat wheelRadius = bodyWidth * 0.085;
    CGFloat bob = sin(self.time * 14.0) * 1.2;
    CGFloat baseY = roadY - wheelRadius - 2.0 + bob;

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, carX, baseY);

    // Shadow
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.35].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(-bodyWidth * 0.5, 6.0, bodyWidth, wheelRadius * 1.4));

    // Lower body
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.95 alpha:1.0].CGColor);
    CGRect bodyRect = CGRectMake(-bodyWidth * 0.5, -bodyHeight * 0.62, bodyWidth, bodyHeight * 0.62);
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:bodyRect cornerRadius:bodyHeight * 0.12];
    CGContextAddPath(ctx, body.CGPath);
    CGContextFillPath(ctx);

    // Cabin
    CGRect cabinRect = CGRectMake(-bodyWidth * 0.26, -bodyHeight * 1.16, bodyWidth * 0.58, bodyHeight * 0.58);
    UIBezierPath *cabin = [UIBezierPath bezierPathWithRoundedRect:cabinRect cornerRadius:bodyHeight * 0.10];
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.97 alpha:1.0].CGColor);
    CGContextAddPath(ctx, cabin.CGPath);
    CGContextFillPath(ctx);

    // Windows
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.07 green:0.09 blue:0.14 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(cabinRect.origin.x + 5.0, cabinRect.origin.y + 5.0,
                                      cabinRect.size.width * 0.44, cabinRect.size.height - 10.0));
    CGContextFillRect(ctx, CGRectMake(cabinRect.origin.x + cabinRect.size.width * 0.52, cabinRect.origin.y + 5.0,
                                      cabinRect.size.width * 0.42, cabinRect.size.height - 10.0));

    // Black door band, the classic patrol car look
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.08 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(-bodyWidth * 0.5, -bodyHeight * 0.40, bodyWidth, bodyHeight * 0.16));

    // Light bar
    CGRect barRect = CGRectMake(-bodyWidth * 0.14, -bodyHeight * 1.30, bodyWidth * 0.30, bodyHeight * 0.14);
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.15 alpha:1.0].CGColor);
    CGContextFillRect(ctx, barRect);

    BOOL redPhase = fmod(self.time, 0.5) < 0.25;
    CGContextSetFillColorWithColor(ctx, [(redPhase ? [UIColor redColor] : [UIColor blueColor]) colorWithAlphaComponent:0.95].CGColor);
    CGContextFillRect(ctx, CGRectMake(barRect.origin.x + 1.0, barRect.origin.y + 1.0,
                                      barRect.size.width * 0.5 - 1.5, barRect.size.height - 2.0));
    CGContextSetFillColorWithColor(ctx, [(redPhase ? [UIColor blueColor] : [UIColor redColor]) colorWithAlphaComponent:0.95].CGColor);
    CGContextFillRect(ctx, CGRectMake(barRect.origin.x + barRect.size.width * 0.5 + 0.5, barRect.origin.y + 1.0,
                                      barRect.size.width * 0.5 - 1.5, barRect.size.height - 2.0));

    // Wheels
    for (CGFloat sign = -1.0; sign <= 1.0; sign += 2.0) {
        CGFloat wheelX = sign * bodyWidth * 0.29;
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.05 alpha:1.0].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(wheelX - wheelRadius, -wheelRadius * 2.0,
                                                    wheelRadius * 2.0, wheelRadius * 2.0));
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.55 alpha:1.0].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(wheelX - wheelRadius * 0.42, -wheelRadius * 1.42,
                                                    wheelRadius * 0.84, wheelRadius * 0.84));
    }

    CGContextRestoreGState(ctx);
}

- (void)drawPedestrianInContext:(CGContextRef)ctx
                            atX:(CGFloat)x
                        groundY:(CGFloat)groundY
                        yOffset:(CGFloat)yOffset
                       rotation:(CGFloat)rotation
                      walkPhase:(CGFloat)walkPhase
                        knocked:(BOOL)knocked
{
    CGFloat height = 46.0;

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, x, groundY - yOffset);
    if (knocked) {
        CGContextRotateCTM(ctx, rotation);
    }

    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineWidth(ctx, 3.0);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.05 alpha:0.95].CGColor);
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.05 alpha:0.95].CGColor);

    // Head
    CGContextFillEllipseInRect(ctx, CGRectMake(-4.0, -height, 8.0, 8.0));

    // Torso
    CGContextMoveToPoint(ctx, 0.0, -height + 8.0);
    CGContextAddLineToPoint(ctx, 0.0, -height * 0.45);

    // Arms
    CGFloat swing = knocked ? 0.9 : sin(walkPhase) * 0.6;
    CGContextMoveToPoint(ctx, 0.0, -height * 0.82);
    CGContextAddLineToPoint(ctx, -7.0, -height * 0.60 + swing * 5.0);
    CGContextMoveToPoint(ctx, 0.0, -height * 0.82);
    CGContextAddLineToPoint(ctx, 7.0, -height * 0.60 - swing * 5.0);

    // Legs
    CGFloat stride = knocked ? 0.8 : sin(walkPhase) * 0.9;
    CGContextMoveToPoint(ctx, 0.0, -height * 0.45);
    CGContextAddLineToPoint(ctx, stride * 8.0, 0.0);
    CGContextMoveToPoint(ctx, 0.0, -height * 0.45);
    CGContextAddLineToPoint(ctx, -stride * 8.0, 0.0);

    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

static void DOPathAddStar(CGContextRef ctx, CGPoint center, CGFloat radius)
{
    CGMutablePathRef path = CGPathCreateMutable();
    for (NSInteger i = 0; i < 10; i++) {
        CGFloat r = (i % 2 == 0) ? radius : radius * 0.45;
        CGFloat angle = (CGFloat)i * M_PI / 5.0 - M_PI_2;
        CGPoint point = CGPointMake(center.x + cos(angle) * r, center.y + sin(angle) * r);
        if (i == 0) {
            CGPathMoveToPoint(path, NULL, point.x, point.y);
        } else {
            CGPathAddLineToPoint(path, NULL, point.x, point.y);
        }
    }
    CGPathCloseSubpath(path);
    CGContextAddPath(ctx, path);
    CGPathRelease(path);
}

- (void)drawWantedStarsInContext:(CGContextRef)ctx size:(CGSize)size
{
    CGFloat radius = MIN(13.0, size.width * 0.030);
    CGFloat spacing = radius * 2.7;
    CGFloat startX = size.width - 26.0 - spacing * (DO_MAX_STARS - 1) - radius;
    CGFloat y = 62.0;

    for (NSInteger i = 0; i < DO_MAX_STARS; i++) {
        CGPoint center = CGPointMake(startX + (CGFloat)i * spacing, y);
        DOPathAddStar(ctx, center, radius);
        if (i < self.wantedLevel) {
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.80 blue:0.15 alpha:1.0].CGColor);
            CGContextFillPath(ctx);
        } else {
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.40].CGColor);
            CGContextSetLineWidth(ctx, 1.5);
            CGContextStrokePath(ctx);
        }
    }
}

- (void)drawWastedInContext:(CGContextRef)ctx size:(CGSize)size
{
    // Darken the scene behind the message
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.45].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));

    CGFloat fontSize = MIN(size.width * 0.20, 76.0);
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [UIColor colorWithRed:0.45 green:0.0 blue:0.0 alpha:0.9];
    shadow.shadowBlurRadius = fontSize * 0.18;
    shadow.shadowOffset = CGSizeZero;

    NSMutableParagraphStyle *centered = [[NSMutableParagraphStyle alloc] init];
    centered.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:fontSize weight:UIFontWeightBlack],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.93 alpha:1.0],
        NSKernAttributeName: @(fontSize * 0.04),
        NSShadowAttributeName: shadow,
        NSParagraphStyleAttributeName: centered,
    };

    NSString *wasted = @"WASTED";
    CGSize textSize = [wasted sizeWithAttributes:attributes];
    CGFloat y = size.height * 0.45 - textSize.height * 0.5;
    [wasted drawInRect:CGRectMake(0, y, size.width, textSize.height + 8) withAttributes:attributes];
}

- (void)dealloc
{
    [self.displayLink invalidate];
}

@end
