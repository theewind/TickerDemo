//
//  JHTickerView.m
//  Ticker
//
//  Created by Jeff Hodnett on 03/05/2011.
//  Copyright 2011 Applausible. All rights reserved.
//

#import "JHTickerView.h"
#import <QuartzCore/QuartzCore.h>
#import "ReactiveCocoa.h"
// Defaults
static NSString *kDefaultTickerFontName = @"Marker Felt";
static const BOOL kDefaultTickerDoesLoop = YES;
static const JHTickerDirection kDefaultTickerDirection = JHTickerDirectionLTR;

@interface JHTickerView()
{
	// The current index for the string
	int _currentIndex;
	
	// The current state of the ticker
	BOOL _isRunning;
	
	// The ticker label
	UILabel *_tickerLabel;
    UILabel *_tickerLabel2;
    CGSize _textSize;
}

@property(nonatomic, strong) UIFont *font;
@property(nonatomic, strong) NSMutableArray *tickerStrings;

-(void)setupView;
-(void)animateCurrentTickerString;
-(void)pauseLayer:(CALayer *)layer;
-(void)resumeLayer:(CALayer *)layer;
@end

@implementation JHTickerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		[self setupView];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	if( (self = [super initWithCoder:aDecoder]) ) {
		// Initialization code
		[self setupView];
	}
	return self;
}

-(void)setTickerSpeed:(CGFloat)tickerSpeed
{
    _tickerSpeed = tickerSpeed;
    
    // Disallow less than zero ticker speeds
    if(_tickerSpeed <= 0.0f) {
        _tickerSpeed = 0.1f;
    }
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[_tickerLabel release];
    [_font release];
    [_tickerStrings release];
    
    [super dealloc];
}
#endif

-(void)setupView
{
	// Set background color to white
	[self setBackgroundColor:[UIColor whiteColor]];
	
	// Set a corner radius
	[self.layer setCornerRadius:5.0f];
	[self.layer setBorderWidth:2.0f];
	[self.layer setBorderColor:[UIColor blackColor].CGColor];
	[self setClipsToBounds:YES];
	
	// Set the font
    self.font = [UIFont fontWithName:kDefaultTickerFontName size:22.0];
    
	// Add the ticker label
    _tickerLabel = [[UILabel alloc] initWithFrame:self.bounds];
	[_tickerLabel setBackgroundColor:[UIColor grayColor]];
	[_tickerLabel setNumberOfLines:1];
    [_tickerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[_tickerLabel setFont:self.font];
    [_tickerLabel setAdjustsFontSizeToFitWidth:YES];
	[self addSubview:_tickerLabel];

    CGRect frame = self.bounds;
    frame.origin.x = _tickerLabel.frame.size.width;
    _tickerLabel2 = [[UILabel alloc] initWithFrame:frame];
    [_tickerLabel2 setBackgroundColor:[UIColor lightGrayColor]];
    [_tickerLabel2 setNumberOfLines:1];
    [_tickerLabel2 setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_tickerLabel2 setFont:self.font];
    [_tickerLabel2 setAdjustsFontSizeToFitWidth:YES];
    [self addSubview:_tickerLabel2];
    
	// Set that it loops by default
	self.loops = kDefaultTickerDoesLoop;
    
    // Set the default direction
    self.direction = kDefaultTickerDirection;
    self.gap = 40;
    
    RAC(_tickerLabel2, font) = RACObserve(_tickerLabel, font);
    RAC(_tickerLabel2, text) = RACObserve(_tickerLabel, text);
}

-(void)setTickerFont:(UIFont *)font
{
    self.font = font;
    [_tickerLabel setFont:self.font];
    [_tickerLabel2 setFont:self.font];
}

-(void)setTickerText:(NSArray *)text
{
    // Error check
    if (text == nil || [text count] == 0) {
        return;
    }
    
    self.tickerStrings = [NSMutableArray arrayWithArray:text];
}

-(void)addTickerText:(id)text
{
    [self.tickerStrings addObject:text];
}

-(void)removeAllTickerText
{
    [self.tickerStrings removeAllObjects];
}

-(void)animateCurrentTickerString
{
	id currentTickerString = [_tickerStrings objectAtIndex:_currentIndex];
	
	// Calculate the size of the text and update the frame size of the ticker label
    CGSize textSize = CGSizeZero;
    CGSize maxSize = CGSizeMake(MAXFLOAT, CGRectGetHeight(self.bounds));
    NSString *currentString = nil;
    if([currentTickerString isKindOfClass:[NSAttributedString class]]) {
        currentString = [currentTickerString string];
    }
    else {
        currentString = currentTickerString;
    }
    
    // Calculate size
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
    NSDictionary *textAttributes = nil;
    if([currentTickerString isKindOfClass:[NSAttributedString class]]) {
        // Use the NSAttributedString attributes
        textAttributes = [currentTickerString attributesAtIndex:0 effectiveRange:NULL];
    }
    else {
        // Use this labels attributes
        textAttributes = @{
                           NSFontAttributeName: _tickerLabel.font
                           };
    }
    CGRect textRect = [currentString boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes context:nil];
    textSize = textRect.size;
#else
    textSize = [currentString sizeWithFont:_tickerLabel.font constrainedToSize:maxSize lineBreakMode:UILineBreakModeWordWrap];
#endif

    textSize.width += self.gap/2;
    _textSize = textSize;
   
	// Set starting position
	[_tickerLabel setFrame:CGRectMake(0, _tickerLabel.frame.origin.y, textSize.width, maxSize.height)];
	[_tickerLabel2 setFrame:CGRectMake(_textSize.width, _tickerLabel.frame.origin.y, textSize.width, maxSize.height)];
	
    // Set the string
    if([currentTickerString isKindOfClass:[NSAttributedString class]]) {
        [_tickerLabel setAttributedText:currentTickerString];
    }
    else {
        [_tickerLabel setText:currentString];
    }
		
	// Calculate a uniform duration for the item
    static CGFloat delay = 1.0;
	CGFloat duration = (2 * textSize.width - self.frame.size.width) / self.tickerSpeed;
    CGFloat duration2 = self.frame.size.width / self.tickerSpeed;
    
    [self alignLabelToLeft:_tickerLabel];
    [UIView animateWithDuration:duration delay:delay options:UIViewAnimationOptionCurveLinear animations:^{
        [_tickerLabel setFrame:CGRectMake(self.frame.size.width-2*textSize.width, _tickerLabel.frame.origin.y, textSize.width, maxSize.height)];
        [_tickerLabel2 setFrame:CGRectMake(self.frame.size.width-_textSize.width, _tickerLabel2.frame.origin.y, textSize.width, maxSize.height)];
        
    } completion:^(BOOL finished) {
        [_tickerLabel setFrame:CGRectMake(self.frame.size.width, _tickerLabel.frame.origin.y, textSize.width, maxSize.height)];
        delay = 0;
        [UIView animateWithDuration:duration2 delay:delay options:UIViewAnimationOptionCurveLinear animations:^{
            [_tickerLabel setFrame:CGRectMake(0, _tickerLabel.frame.origin.y, textSize.width, maxSize.height)];
            [_tickerLabel2 setFrame:CGRectMake(-textSize.width, _tickerLabel2.frame.origin.y, textSize.width, maxSize.height)];
        } completion:^(BOOL finished) {
            [self animateCurrentTickerString];
        }];
    }];
}


- (void)alignLabelToLeft:(UILabel*)label {
    CGRect frame = label.frame;
    frame.origin.x = 0;
    label.frame = frame;
}

- (void)alignLabelToRight:(UILabel*)label {
    CGRect frame = label.frame;
    frame.origin.x = self.frame.size.width - _textSize.width;
    label.frame = frame;
}

- (void)hiddenLabelAtLeft:(UILabel*)label {
    CGRect frame = label.frame;
    frame.origin.x = -_textSize.width;
    label.frame = frame;
}

- (void)hiddenLabelAtRight:(UILabel*)label {
    CGRect frame = label.frame;
    frame.origin.x = self.frame.size.width;
    label.frame = frame;
}



#pragma mark - Ticker Animation Handling

-(void)start
{
	// Set the index to 0 on starting
	_currentIndex = 0;
	
	// Set running
	_isRunning = YES;
	
	// Start the animation
	[self animateCurrentTickerString];
}

-(void)pause
{
	// Check if running
	if(_isRunning) {
		// Pause the layer
		[self pauseLayer:self.layer];
		
		_isRunning = NO;
	}
}

-(void)resume
{
	// Check not running
	if(!_isRunning) { 
		// Resume the layer
		[self resumeLayer:self.layer];
		
		_isRunning = YES;
	}
}

#pragma mark - UIView layer animations utilities
-(void)pauseLayer:(CALayer *)layer
{
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

-(void)resumeLayer:(CALayer *)layer
{
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

@end
