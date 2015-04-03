#import "MainScene.h"
#import <GoogleIAB/GoogleIAB.h>

#import <AndroidKit/AndroidAlertDialogBuilder.h>
#import <AndroidKit/AndroidSharedPreferences.h>
#import <AndroidKit/AndroidSharedPreferencesEditor.h>

extern NSString *ITEM_TYPE_SUBS;
extern NSString *ITEM_TYPE_INAPP;

// SKUs for our products: the premium upgrade (non-consumable) and gas (consumable)
static NSString *SKU_PREMIUM = @"premium";
static NSString *SKU_GAS = @"gas";

// SKU for our subscription (infinite gas)
static NSString *SKU_INFINITE_GAS = @"infinite_gas";

// (arbitrary) request code for the purchase flow
static int RC_REQUEST = 10001;

// How many units (1/4 tank is our unit) fill in the tank.
static int TANK_MAX = 4;

@interface MainScene ()

// Does the user have the premium upgrade?
@property (nonatomic, assign) BOOL isPremium;

// Does the user have an active subscription to the infinite gas plan?
@property (nonatomic, assign) BOOL subscribedToInfiniteGas;

// Current amount of gas in tank, in units
@property (nonatomic, assign) int tank;

// Listener that's called when we finish querying the items and subscriptions we own
@property (nonatomic, copy) void (^gotInventoryListener)(IABResult *result, IABInventory *inventory);

// Called when consumption is complete
@property (nonatomic, copy) void (^consumeFinishedListener)(IABPurchase *purchase, IABResult *result);

// Callback for when a purchase is finished
@property (nonatomic, copy) void (^purchaseFinishedListener)(IABResult *result, IABPurchase *purchase);

@end

@implementation MainScene

@synthesize waitView,gasIndicator,freeOrPremium, helper=_helper;

-(void)onEnter {
    [super onEnter];
    
    [self loadData];
    
    __weak MainScene *weakSelf = self;
    
    _gotInventoryListener = ^(IABResult *result, IABInventory *inventory) {
        NSLog(@"Query inventory finished.");
        
        // Have we been disposed of in the meantime? If so, quit.
        if (!weakSelf.helper) {
            return;
        }
        
        // Is it a failure?
        if (result.isFailure) {
            [weakSelf complain:[NSString stringWithFormat:@"Failed to query inventory: %@", result]];
            return;
        }
        
        NSLog(@"Query inventory was successful.");
        
        /*
         * Check for items we own. Notice that for each purchase, we check
         * the developer payload to see if it's correct! See
         * verifyDeveloperPayload().
         */
        
        // Do we have the premium upgrade?
        IABPurchase *premiumPurchase = [inventory getPurchase:SKU_PREMIUM];
        weakSelf.isPremium = (premiumPurchase != nil && [weakSelf verifyDeveloperPayload:premiumPurchase]);
        NSLog(@"User is %@", weakSelf.isPremium ? @"PREMIUM" : @"NOT PREMIUM");
        
        // Do we have the infinite gas plan?
        IABPurchase *infiniteGasPurchase = [inventory getPurchase:SKU_INFINITE_GAS];
        weakSelf.subscribedToInfiniteGas = (infiniteGasPurchase != nil && [weakSelf verifyDeveloperPayload:infiniteGasPurchase]);
        NSLog(@"User %@ infinite gas subscription.", weakSelf.subscribedToInfiniteGas ? @"HAS" : @"DOES NOT HAVE");
        
        // Check for gas delivery -- if we own gas, we should fill up the tank immediately
        IABPurchase *gasPurchase = [inventory getPurchase:SKU_GAS];
        if (gasPurchase != nil && [weakSelf verifyDeveloperPayload:gasPurchase]) {
            NSLog(@"We have gas. COnsuming it.");
            [weakSelf.helper consumeAsync:[inventory getPurchase:SKU_GAS] onConsumeFinished:weakSelf.consumeFinishedListener];
            return;
        }
        
        [weakSelf updateUI];
        [weakSelf setWaitScreen:NO];
        NSLog(@"Initial inventory query finished; enabling main UI.");
    };
    
    _consumeFinishedListener = ^(IABPurchase *purchase, IABResult *result) {
        NSLog(@"Consumption finished. Purchase: %@, result: %@", purchase, result);
        
        // if we were disposed of in the meantime, quit.
        if (!weakSelf.helper) {
            return;
        }
        
        // We know this is the "gas" sku because it's the only one we consume,
        // so we don't check which sku was consumed. If you have more than one
        // sku, you probably should check...
        if (result.isSuccess) {
            // successfully consumed, so we apply the effects of the item in our
            // game world's logic, which in our case means filling the gas tank a bit
            NSLog(@"Consumption successful. Provisioning.");
            weakSelf.tank = weakSelf.tank == TANK_MAX ? TANK_MAX : weakSelf.tank + 1;
            [weakSelf saveData];
            [weakSelf alert:[NSString stringWithFormat:@"You filled 1/4 tank. Your tank is now %d/4 full!", weakSelf.tank]];
        } else {
            [weakSelf complain:[NSString stringWithFormat:@"Error while consuming: %@", result]];
        }
        [weakSelf updateUI];
        [weakSelf setWaitScreen:NO];
        NSLog(@"End consumption flow.");
    };
    
    _purchaseFinishedListener = ^(IABResult *result, IABPurchase *purchase) {
        NSLog(@"Purchase finished: %@, purchase: %@", result, purchase);
        
        // if we were disposed of in the meantime, quit.
        if (weakSelf.helper == nil) {
            return;
        }
        
        if (result.isFailure) {
            [weakSelf complain:[NSString stringWithFormat:@"Error purchasing: %@", result]];
            [weakSelf setWaitScreen:NO];
            return;
        }
        
        if (![weakSelf verifyDeveloperPayload:purchase]) {
            [weakSelf complain:@"Error purchasing. Authenticity verification failed."];
            [weakSelf setWaitScreen:NO];
            return;
        }
        
        NSLog(@"Purchase successful.");
        
        if ([[purchase sku] isEqualToString:SKU_GAS]) {
            // bought 1/4 tank of gas. So consume it.
            NSLog(@"Purchase is gas. Starting gas consumption.");
            [weakSelf.helper consumeAsync:purchase onConsumeFinished:weakSelf.consumeFinishedListener];
        } else if ([[purchase sku] isEqualToString:SKU_PREMIUM]) {
            // bought the premium upgrade!
            NSLog(@"Purchase is premium upgrade. Congratulating user.");
            [weakSelf alert:@"Thank you for upgrading to premium!"];
            weakSelf.isPremium = true;
            [weakSelf updateUI];
            [weakSelf setWaitScreen:NO];
        } else if ([[purchase sku] isEqualToString:SKU_INFINITE_GAS]) {
            NSLog(@"Infinite gas subscription purchased.");
            [weakSelf alert:@"Thank you for subscribing to infinite gas!"];
            weakSelf.subscribedToInfiniteGas = YES;
            weakSelf.tank = TANK_MAX;
            [weakSelf updateUI];
            [weakSelf setWaitScreen:NO];
        }
    };
    
    [self setWaitScreen:NO];
    
    /* base64EncodedPublicKey should be YOUR APPLICATION'S PUBLIC KEY
     * (that you got from the Google Play developer console). This is not your
     * developer public key, it's the *app-specific* public key.
     *
     * Instead of just storing the entire literal string here embedded in the
     * program,  construct the key at runtime from pieces or
     * use bit manipulation (for example, XOR with some other string) to hide
     * the actual key.  The key itself is not secret information, but we don't
     * want to make it easy for an attacker to replace the public key with one
     * of their own and then fake messages from the server.
     */
    NSString *base64EncodedPublicKey = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA14lOJyW3Yv/b/7r1uHuZk0vRUxZcACvBiYzaExmX5AUliaaa62KJ7y0tQVtxtZoN/MHWwQdHARIw6kQbje/k68mmXLtK+v6/CchXC+tOML3de7u7mnnwdk/lQB9SYoLh+h/B/dp8SFBqrTMnugsAgU5wRE22u7Squcu85+UNntpiXRAVcUwcv6RtjG9+Lfe4IFY8d4IFEcBUjg7jRuhAp/vjj7MV8jZLFKB7HV5egrMJf9/zd1yXvMAdvnSTVbthTpCyjMOmRrEgQnZZ0cxwpAIxbUaCYcnc1uF4/A4qsOYSYDEHCcDMqhGGLS4zCzsNwOxbfilsg7oj7D5NiNJD0wIDAQAB";

    // Create the helper, passing it our context and the public key to verify signatures with
    NSLog(@"Creating IAB helper.");
    _helper = [[IABHelper alloc] initWithContext:[CCActivity currentActivity] andBase64EncodedPublicKey:base64EncodedPublicKey];
    
    // enable debug logging (for a production application, you should set this to false).
    [_helper enableDebugLogging:YES];
    
    // Start setup. This is asynchronous and the specified listener
    // will be called once setup completes.
    NSLog(@"Starting setup");
    [_helper startSetup:^(IABResult *result) {
        NSLog(@"Setup finished");
        
        if (!result.isSuccess) {
            [self complain:[NSString stringWithFormat:@"Problem setting up in-app billing: %@", result]];
            return;
        }
        
        // Have we been disposed of in the meantime? If so, quit.
        if (!_helper) {
            return;
        }
        
        // IAB is fully set up. Now, let's get an inventory of stuff we own.
        NSLog(@"Setup successful. Querying inventory.");
        [_helper queryInventoryAsync:_gotInventoryListener];
    } withSignatureVerifyListener:^BOOL(NSString *_signatureBase64, NSString *purchaseData, NSString *dataSignature) {
        // This is a naive signature verification process.
        
        //At least verify that the signature was real:
        return [IABSecurity verifyPurchase:base64EncodedPublicKey signedData:purchaseData signature:dataSignature];
        //You should probably do more to verify that everything is correct here. Validate purchaseData, etc.
    }];

}

- (void)setWaitScreen:(BOOL)wait {
    self.waitView.visible = wait;
}

-(void)updateUI {
    if (_isPremium) {
        [freeOrPremium setSpriteFrame:[CCSpriteFrame frameWithImageNamed:@"assets/premium.png"]];
    }
    
    if (_subscribedToInfiniteGas) {
        [gasIndicator setSpriteFrame:[CCSpriteFrame frameWithImageNamed:@"assets/gas_inf.png"]];
    }
    else {
        [gasIndicator setSpriteFrame:[CCSpriteFrame frameWithImageNamed:[NSString stringWithFormat:@"assets/gas%d.png",MIN(TANK_MAX, _tank)]]];
    }
}

- (void)complain:(NSString *)message
{
    NSLog(@"**** TrivialDrive Error: %@", message);
    [self alert:message];
}

- (void)alert:(NSString *)message
{
    dispatch_async(dispatch_get_main_android_queue(), ^{
        AndroidAlertDialogBuilder *bld = [[AndroidAlertDialogBuilder alloc] initWithContext:[CCActivity currentActivity]];
        [bld setMessageByCharSequence:message];
        [bld setNeutralButtonWithText:@"OK" onClickListener:nil];
        NSLog(@"Showing alert dialog: %@", message);
        [bld show];
    });
}

- (void) upgradeAppPressed:(CCButton *)sender {
    NSLog(@"Upgrade button clicked; launching purchase flow for upgrade.");
    [self setWaitScreen:YES];
    /* TODO: for security, generate your payload here for verification. See the comments on
     *        verifyDeveloperPayload() for more info. Since this is a SAMPLE, we just use
     *        an empty string, but on a production app you should carefully generate this. */
    NSString *payload = @"";
    [_helper launchPurchaseFlow:[CCActivity currentActivity] sku:SKU_PREMIUM requestCode:RC_REQUEST onIabPurchaseFinished:_purchaseFinishedListener extraData:payload];
}

- (void)infiniteGasPurchasePressed:(CCButton *)sender {
    if (!_helper.subscriptionsSupported) {
        [self complain:@"Subscriptions not supported on your device yet. Sorry!"];
        return;
    }
    
    NSString *payload = @"";
    [self setWaitScreen:YES];
    NSLog(@"Launching purchase flow for infinite gas subscription.");
    [_helper launchPurchaseFlow:[CCActivity currentActivity] sku:SKU_INFINITE_GAS itemType:ITEM_TYPE_SUBS requestCode:RC_REQUEST onIabPurchaseFinished:_purchaseFinishedListener extraData:payload];
}

-(void)drivePressed:(CCButton *)sender {
    NSLog(@"Drive button clicked.");
    if (!_subscribedToInfiniteGas && _tank <= 0) {
        [self alert:@"Oh, no! You are out of gas! Try buying some!"];
    } else {
        if (!_subscribedToInfiniteGas) {
            --_tank;
        }
        [self saveData];
        [self alert:@"Vroooom, you drove a few miles."];
        [self updateUI];
        NSLog(@"Vrooom. Tank is now %d", _tank);
    }
}

-(void)buyGasPressed:(CCButton *)sender {
    NSLog(@"Buy gas button clicked.");
    
    if (_subscribedToInfiniteGas) {
        [self complain:@"No need! You're subscribed to infinite gas. Isn't that awesome?"];
        return;
    }
    
    if (_tank >= TANK_MAX) {
        [self complain:@"Your tank is full. Drive around a bit!"];
        return;
    }
    // launch the gas purchase UI flow.
    // We will be notified of completion via mPurchaseFinishedListener
    [self setWaitScreen:YES];
    NSLog(@"Launching purchase flow for gas.");
    
    /* TODO: for security, generate your payload here for verification. See the comments on
     *        verifyDeveloperPayload() for more info. Since this is a SAMPLE, we just use
     *        an empty string, but on a production app you should carefully generate this. */
    NSString *payload = @"";
    [_helper launchPurchaseFlow:[CCActivity currentActivity] sku:SKU_GAS requestCode:RC_REQUEST onIabPurchaseFinished:_purchaseFinishedListener extraData:payload];

}

/** Verifies the developer payload of a purchase. */
- (BOOL) verifyDeveloperPayload:(IABPurchase *)p {
    NSString *payload = p.developerPayload;
    
    /*
     * TODO: verify that the developer payload of the purchase is correct. It will be
     * the same one that you sent when initiating the purchase.
     *
     * WARNING: Locally generating a random string when starting a purchase and
     * verifying it here might seem like a good approach, but this will fail in the
     * case where the user purchases an item on one device and then uses your app on
     * a different device, because on the other device you will not have access to the
     * random string you originally generated.
     *
     * So a good developer payload has these characteristics:
     *
     * 1. If two different users purchase an item, the payload is different between them,
     *    so that one user's purchase can't be replayed to another user.
     *
     * 2. The payload must be such that you can verify it even when the app wasn't the
     *    one who initiated the purchase flow (so that items purchased by the user on
     *    one device work on other devices owned by the user).
     *
     * Using your own server to store and verify developer payloads across app
     * installations is recommended.
     */
    
    return YES;
}

- (void) saveData {
    
    /*
     * WARNING: on a real application, we recommend you save data in a secure way to
     * prevent tampering. For simplicity in this sample, we simply store the data using a
     * SharedPreferences.
     */
    
    JavaObject<AndroidSharedPreferencesEditor> *spe = [[[CCActivity currentActivity] preferencesForMode:AndroidContextModePrivate] edit];
    [spe putInt:@"tank" intValue:_tank];
    [spe commit];
    NSLog(@"Saved data: tank = %d", _tank);
}

- (void)loadData
{
    id<AndroidSharedPreferences> sp = [[CCActivity currentActivity] preferencesForMode:AndroidContextModePrivate];
    _tank = [sp intValueForKey:@"tank" defValue:4];
    NSLog(@"Loaded data: tank = %d", _tank);
}

@end
