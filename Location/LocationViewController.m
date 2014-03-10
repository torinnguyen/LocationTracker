//
//  LocationViewController.m
//  Location
//
//  Created by Rick. Modified by Torin Nguyen
//  Copyright (c) 2014 Location. All rights reserved.
//

#import "LocationViewController.h"
#import "LocationTracker.h"
#import "ServerApiManager.h"
#import <MapKit/MapKit.h>

@interface LocationViewController ()
@property (nonatomic, weak) IBOutlet UILabel * label;
@property (nonatomic, weak) IBOutlet MKMapView * mapView;

@property (nonatomic, strong) NSTimer * refresh_timer;
@property (nonatomic, strong) NSMutableArray * locations;
@end

@implementation LocationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.locations = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.refresh_timer = [NSTimer scheduledTimerWithTimeInterval:0.456
                                                          target:self
                                                        selector:@selector(onRefreshTimer:)
                                                        userInfo:nil
                                                         repeats:YES];
    
    //Assuming here user has just logged in & presented with a nice instruction to enable Location Server (see the label)
    [[LocationTracker sharedInstance] setCallbackBlock:^(id object) {
        [self didReceiveNewLocationCallback:object];
    }];
    [[LocationTracker sharedInstance] startLocationTracking];
    [LocationTracker sharedInstance].minimumCallBackInterval = 60;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.refresh_timer) {
        [self.refresh_timer invalidate];
        self.refresh_timer = nil;
    }
    
    [[LocationTracker sharedInstance] setCallbackBlock:nil];
}



#pragma mark - Helpers

- (void)updateLabel
{
    //User has not yet being prompt for location service permission
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus == kCLAuthorizationStatusNotDetermined) {
        self.label.text = @"Please authorize Location Service\nto use this App";
        return;
    }
        
    //User denied access to Location Service
    if (authorizationStatus == kCLAuthorizationStatusDenied || authorizationStatus == kCLAuthorizationStatusRestricted) {
        self.label.text = @"You have to enable the Location Service to use this App. To enable, please go to Settings->Privacy->Location Services->LocationTracker (ON)";
        return;
    }
    
    CLLocation * lastLocation = [LocationTracker sharedInstance].myLastLocation;
    NSTimeInterval intervalSinceLastUpdate = fabsf([[LocationTracker sharedInstance].myLastLocationTime timeIntervalSinceNow]);
    
    NSString * logMessage = [NSString stringWithFormat:@"Lat: %.5f\nLon: %.5f\nAccuracy: %.2fm\n%.2f seconds", lastLocation.coordinate.latitude, lastLocation.coordinate.longitude, lastLocation.horizontalAccuracy, intervalSinceLastUpdate];
    self.label.text = logMessage;
}



#pragma mark - Actions

- (void)onRefreshTimer:(NSTimer *)timer
{
    [self updateLabel];
}



#pragma mark - Map

- (void)updateMap
{
    //App is in background, do nothing
    if ( ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ||
        ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive))
        return;
    
    //Bruteforce implementation to update all annotation on the map
    
    //Clear previous map
    [self.mapView removeAnnotations:self.mapView.annotations];

    //Re-Add all annotations
    for (CLLocation * location in self.locations)
    {
        // Add an annotation to the map
        MKPointAnnotation * annotation = [[MKPointAnnotation alloc] init];
        annotation.coordinate = location.coordinate;
        [self.mapView addAnnotation:annotation];
    }
    
    [self.mapView showAnnotations:self.mapView.annotations animated:YES];
}

/*
 * This function is triggered by LocationTracker at most once every minute (because we configure it so)
 */
- (void)didReceiveNewLocationCallback:(CLLocation *)location
{
    //Sanity check
    if ([location isKindOfClass:[CLLocation class]] == NO)
        return;
    
    [self.locations addObject:location];
    [self updateMap];
    [self updateLabel];
    [[ServerApiManager sharedInstance] updateLocationToServerInBackground:location];
}

@end
