//
//  LocationAppDelegate.m
//  Location
//
//  Created by Rick. Modified by Torin Nguyen
//  Copyright (c) 2014 Location. All rights reserved.
//

#import "LocationAppDelegate.h"
#import "LocationTracker.h"

@implementation LocationAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Reference:
    //http://stackoverflow.com/questions/3421242/behaviour-for-significant-change-location-api-when-terminated-suspended
    if ([launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey])
    {
        LocationTracker * locationTracker = [LocationTracker sharedInstance];
        [locationTracker startLocationTracking];
        return YES;
    }
    
    //This should not be here, UX problem
    //We should only ask user for Location Service permission after user has logged in, or presented with substaintial tutorial
    //LocationTracker * locationTracker = [LocationTracker sharedInstance];
    //[locationTracker startLocationTracking];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
