@class IABHelper;

@interface MainScene : CCNode

@property (nonatomic, retain) CCNodeColor* waitView;
@property (nonatomic, retain) CCSprite* gasIndicator;
@property (nonatomic, retain) CCSprite* freeOrPremium;
@property (nonatomic, retain) IABHelper* helper;

@end
