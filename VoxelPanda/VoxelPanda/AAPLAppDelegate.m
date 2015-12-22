/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The app delegate is a supporting class within the scope of this sample.
 */
#import "AAPLAppDelegate.h"

@interface AAPLAppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AAPLAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(nonnull NSApplication *)sender
{
    return YES;
}

@end
