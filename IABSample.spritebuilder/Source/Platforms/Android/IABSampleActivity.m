/*
 * SpriteBuilder: http://www.spritebuilder.org
 *
 * Copyright (c) 2014 Apportable Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


#import "IABSampleActivity.h"
#import "MainScene.h"
#import <GoogleIAB/GoogleIAB.h>

#import <AndroidKit/AndroidIntent.h>
#import <AndroidKit/AndroidKeyEvent.h>

@implementation IABSampleActivity
{
    MainScene* mainScene;
}

- (CCScene *)startScene
{
    CCScene* scene = [CCBReader loadAsScene:@"MainScene"];
    mainScene = [scene children].firstObject;
    return scene;
}

- (BOOL)onKeyUp:(int32_t)keyCode keyEvent:(AndroidKeyEvent *)event
{
    if (keyCode == AndroidKeyEventKeycodeBack)
    {
        [self finish];
    }
    return NO;
}

- (void)onActivityResult:(int)requestCode resultCode:(int)resultCode intent:(AndroidIntent *)intent {
    NSLog(@"onActivityResult(%d,%d,%@)", requestCode, resultCode, intent);
    if (mainScene.helper == nil) {
        return;
    }
    
    // Pass on the activity result to the helper for handling
    if (![mainScene.helper handleActivityResult:requestCode resultCode:resultCode intent:intent]) {
        // not handled, so handle it ourselves (here's where you'd
        // perform any handling of activity results not related to in-app
        // billing...
        [super onActivityResult:requestCode resultCode:resultCode intent:intent];
    }
    else {
        NSLog(@"onActivityResult handled by IABUtil.");
    }
}

@end
