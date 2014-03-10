//
//  LocationTracker.m
//  Location
//
//  Created by Rick. Modified by Torin Nguyen
//  Copyright (c) 2014 Location All rights reserved.
//

#import "LocationTracker.h"
#import <objc/runtime.h>

#define LOCATION_TRACKER_DEFAULT_CALLBACK_INTERVAL      60                      //seconds
#define LOCATION_TRACKER_DEFAULT_INTERVAL               60                      //seconds, foreground mode only
#define LOCATION_TRACKER_ACTIVE_DURATION                8                       //seconds, foreground mode only
#define LOCATION_TRACKER_MAX_LOCATION_AGE               30                      //seconds
#define LOCATION_TRACKER_MAX_LOCATION_HISTORY           100
#define LOCATION_TRACKER_REJECT_LOCATION_ACCURACY       1000                    //meters
#define LOCATION_TRACKER_DISTANCE_FILTER                kCLDistanceFilterNone   //100       //meters, not applicable for significant change service
#define LOCATION_TRACKER_ACCURACY_CLASS                 kCLLocationAccuracyHundredMeters    //not applicable for significant change service

@interface LocationTracker() <CLLocationManagerDelegate>
@property (nonatomic, assign) NSTimeInterval updateInterval;
@property (nonatomic, strong) NSDate * lastCallbackTime;

@property (nonatomic, strong) NSTimer * foregroundTimer;
@property (nonatomic, strong) NSTimer * foregroundDelayedStopTimer;
@end

@implementation LocationTracker

//Singleton for this class
+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static id __singleton = nil;
    dispatch_once(&pred, ^{
        __singleton = [[self alloc] init];
    });
    return __singleton;
}

- (id)init
{
    self = [super init];
    if (self == nil)
        return nil;

    //Initialize internal variables
    self.updateInterval = LOCATION_TRACKER_DEFAULT_INTERVAL;
    self.minimumCallBackInterval = LOCATION_TRACKER_DEFAULT_CALLBACK_INTERVAL;
    self.myLocationArray = [NSMutableArray array];
    self.maxLocationHistory = LOCATION_TRACKER_MAX_LOCATION_HISTORY;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
	return self;
}

//Singleton for the CLLocationManager instance variable
+ (CLLocationManager *)sharedLocationManager;
{
	static CLLocationManager *_locationManager;
	
	@synchronized(self)
    {
		if (_locationManager == nil) {
			_locationManager = [[CLLocationManager alloc] init];
            _locationManager.desiredAccuracy = LOCATION_TRACKER_ACCURACY_CLASS;
		}
	}
	return _locationManager;
}



#pragma mark - Handle application states

- (void)applicationDidEnterBackground
{
    [self logStringToFile:@"applicationDidEnterBackground"];
    
    [self cleanUpAllTimers];
    
    CLLocationManager *locationManager = [LocationTracker sharedLocationManager];
    [locationManager stopUpdatingLocation];
    [locationManager startMonitoringSignificantLocationChanges];
}

- (void)applicationDidBecomeActive
{
    [self logStringToFile:@"applicationDidBecomeActive"];

    [self cleanUpAllTimers];

    CLLocationManager *locationManager = [LocationTracker sharedLocationManager];
    [locationManager stopMonitoringSignificantLocationChanges];

    [self restartLocationUpdates];
}



#pragma mark - Simple helpers

- (void)cleanUpAllTimers
{
    if (self.foregroundTimer) {
        [self.foregroundTimer invalidate];
        self.foregroundTimer = nil;
    }
    if (self.foregroundDelayedStopTimer) {
        [self.foregroundDelayedStopTimer invalidate];
        self.foregroundDelayedStopTimer = nil;
    }
}

- (BOOL)isApplicationInBackgroundMode
{
    return
    ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ||
    ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive);
}

/*
 * Pick out the location with best accuracy in the array
 */
- (CLLocation *)filterBestLocationFromArray:(NSArray *)locationsArray
{
    CLLocation * bestLocation = nil;
    
    for (CLLocation * location in locationsArray)
    {
        //Skip locations older than 30 seconds
        NSTimeInterval locationAge = -[location.timestamp timeIntervalSinceNow];
        if (locationAge > LOCATION_TRACKER_MAX_LOCATION_AGE)
            continue;
        CLLocationCoordinate2D theLocation = location.coordinate;
        CLLocationAccuracy theAccuracy = location.horizontalAccuracy;
        
        //Sanity checks
        if (theAccuracy <= 0 || theAccuracy > LOCATION_TRACKER_REJECT_LOCATION_ACCURACY)
            continue;
        if (theLocation.latitude == 0.0 || theLocation.longitude == 0.0)
            continue;
        
        //First time
        if (bestLocation == nil) {
            bestLocation = location;
            continue;
        }
        
        //identified location is better than this
        if (bestLocation.horizontalAccuracy > location.horizontalAccuracy)
            continue;
        
        bestLocation = location;
    }
    
    return bestLocation;
}



#pragma mark - Public interface

- (void)startLocationTracking
{
    [self startLocationTrackingWithInterval:LOCATION_TRACKER_DEFAULT_INTERVAL];
}

- (void)startLocationTrackingWithInterval:(NSTimeInterval)seconds
{
    if (seconds < 10)
        seconds = LOCATION_TRACKER_DEFAULT_INTERVAL;
    self.updateInterval = seconds;
    
    [self logStringToFile:@"startLocationTracking"];
    
    //Enabled, but might not be authorized yet (first time)
	if ([CLLocationManager locationServicesEnabled] == NO)
    {
        [self logStringToFile:@"locationServicesEnabled false"];
        
		UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                                                        message:@"You currently have all location services for this device disabled"
                                                                       delegate:nil
                                                              cancelButtonTitle:@"OK"
                                                              otherButtonTitles:nil];
		[servicesDisabledAlert show];
        return;
	}
    
    //Has been denied by user before
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus == kCLAuthorizationStatusDenied || authorizationStatus == kCLAuthorizationStatusRestricted)
    {
        [self logStringToFile:@"authorizationStatus failed"];
        return;
    }
    
    [self logStringToFile:@"authorizationStatus authorized"];
    CLLocationManager *locationManager = [LocationTracker sharedLocationManager];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = LOCATION_TRACKER_ACCURACY_CLASS;      //not applicable for significant change service
    locationManager.distanceFilter = LOCATION_TRACKER_DISTANCE_FILTER;      //not applicable for significant change service
    if ([self isApplicationInBackgroundMode])       [locationManager startMonitoringSignificantLocationChanges];
    else                                            [locationManager startUpdatingLocation];
}

- (void)stopLocationTracking
{
    [self logStringToFile:@"stopLocationTracking"];
    
    [self cleanUpAllTimers];
    
	CLLocationManager *locationManager = [LocationTracker sharedLocationManager];
	[locationManager stopUpdatingLocation];
}

- (void)restartLocationUpdates
{
    [self logStringToFile:@"restartLocationUpdates"];
    
    [self cleanUpAllTimers];

    //Enabled, but might not be authorized yet (first time)
	if ([CLLocationManager locationServicesEnabled] == NO)
    {
        [self logStringToFile:@"locationServicesEnabled false"];
        return;
	}
    
    //First time, we haven't asked user yet, don't start anything
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus == kCLAuthorizationStatusNotDetermined)
    {
        [self logStringToFile:@"authorizationStatus kCLAuthorizationStatusNotDetermined"];
        return;
    }
    
    if (authorizationStatus == kCLAuthorizationStatusDenied || authorizationStatus == kCLAuthorizationStatusRestricted)
    {
        [self logStringToFile:@"authorizationStatus failed"];
        return;
    }
    
    CLLocationManager * locationManager = [LocationTracker sharedLocationManager];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = LOCATION_TRACKER_ACCURACY_CLASS;      //not applicable for significant change service
    locationManager.distanceFilter = LOCATION_TRACKER_DISTANCE_FILTER;      //not applicable for significant change service
    if ([self isApplicationInBackgroundMode])       [locationManager startMonitoringSignificantLocationChanges];
    else                                            [locationManager startUpdatingLocation];
}



#pragma mark - CLLocationManagerDelegate Methods

/*
 Note: this will be fired immediately right after startMonitoringSignificantLocationChanges, if...
 the application is waken up with UIApplicationLaunchOptionsLocationKey option
*/
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSTimeInterval timeSinceLastLocationUpdate = fabsf([self.myLastLocationTime timeIntervalSinceNow]);
    self.myLastLocationTime = [NSDate date];
    
    //Special handling when app in background mode
    if ([self isApplicationInBackgroundMode])
    {
        NSString * logMessage = [NSString stringWithFormat:@"locationManager didUpdateLocations in background mode (%lu locations, %.2f secs)", (unsigned long)[locations count], timeSinceLastLocationUpdate];
        [self logStringToFile:logMessage];
    }
    else
    {
        NSString * logMessage = [NSString stringWithFormat:@"locationManager didUpdateLocations in foreground mode (%lu locations, %.2f secs)", (unsigned long)[locations count], timeSinceLastLocationUpdate];
        [self logStringToFile:logMessage];
    }
    
    //Sanity check
    CLLocation * newLocation = [self filterBestLocationFromArray:locations];
    if (newLocation == nil)
        return;
    
    //Keep history of past locations
    self.myLastLocation = newLocation;
    [self.myLocationArray addObject:newLocation];
    while ([self.myLocationArray count] > self.maxLocationHistory && self.maxLocationHistory > 0)
        [self.myLocationArray removeObjectAtIndex:0];
    
    //Debug info
    CLLocationCoordinate2D theLocation = newLocation.coordinate;
    NSString * logMessage = [NSString stringWithFormat:@"%.7f, %.7f Accuracy: %.2f", theLocation.latitude, theLocation.longitude, newLocation.horizontalAccuracy];
    [self logStringToFile:logMessage];
    
    //Callback to whoever is listening (most likely a VC to update UI)
    NSTimeInterval deltaCallback = fabsf([self.lastCallbackTime timeIntervalSinceNow]);
    if (self.lastCallbackTime == nil || deltaCallback > self.minimumCallBackInterval) {
        self.lastCallbackTime = [NSDate date];
        [self performCallbackBlockWithObject:newLocation];
    }
    
    if ([self isApplicationInBackgroundMode])
        return;
    
    //-------------------------------------------------------------------------------------------------
    //The below logic is for when the app is in foreground mode
    //only activate location service for 10 seconds every 1 minute, to save battery
    
    //If the timer still valid (meaning still within 1 minute update interval)
    //This is used as a once-per-minute flag for all the codes below
    if (self.foregroundTimer)
        return;
    
    //Wait for 1 minute then restart the locationManger (foreground)
    self.foregroundTimer = [NSTimer scheduledTimerWithTimeInterval:self.updateInterval
                                                            target:self
                                                          selector:@selector(restartLocationUpdates)
                                                          userInfo:nil
                                                           repeats:NO];
    
    //Will only stop the locationManager after 10 seconds, so that we can get some accurate locations
    //The location manager will only operate for 10 seconds to save battery
    self.foregroundDelayedStopTimer = [NSTimer scheduledTimerWithTimeInterval:LOCATION_TRACKER_ACTIVE_DURATION
                                                                       target:self
                                                                     selector:@selector(stopLocationAfter10Seconds)
                                                                     userInfo:nil
                                                                      repeats:NO];
}

/*
 The location service is only activated for 10 seconds to save battery
 */
- (void)stopLocationAfter10Seconds
{
    if (self.foregroundDelayedStopTimer) {
        [self.foregroundDelayedStopTimer invalidate];
        self.foregroundDelayedStopTimer = nil;
    }
    
    if ([self isApplicationInBackgroundMode])
        return;
    
    CLLocationManager *locationManager = [LocationTracker sharedLocationManager];
    [locationManager stopUpdatingLocation];
    
    [self logStringToFile:@"locationManager stop Updating after 10 seconds"];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    switch ([error code])
    {
        case kCLErrorNetwork: // general, network-related error
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error"
                                                            message:@"Please check your network connection."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [self logStringToFile:@"kCLErrorNetwork"];
        }
            break;
        case kCLErrorDenied:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enable Location Service"
                                                            message:@"You have to enable the Location Service to use this App. To enable, please go to Settings->Privacy->Location Services->LocationTracker (ON)"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [self logStringToFile:@"kCLErrorDenied"];
        }
            break;
        default:
        {
            
        }
            break;
    }
}


#pragma mark - Logging for Debug

- (void)logStringToFile:(NSString *)stringToLog
{
    NSLog(@"%@", stringToLog);
    
    NSString * logFileName = [NSString stringWithFormat:@"%@.log", @"LocationTracker"];
    
    NSDateFormatter * dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
    }
    
    stringToLog = [NSString stringWithFormat:@"%@ --- INFO: %@\n", [dateFormatter stringFromDate:[NSDate date]], stringToLog];
    
    //Get the file path
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:logFileName];
    
    //Create file if it doesn't exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileName])
        [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
    
    //Append text to file (you'll probably want to add a newline every write)
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
    [file seekToEndOfFile];
    [file writeData:[stringToLog dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
}



#pragma mark - Universal callback mechanism

- (void)setCallbackBlock:(void (^)(id object))callbackBlock
{
    //set block as an attribute in runtime
    if (callbackBlock) {
        objc_setAssociatedObject(self, "dismissBlockCallback", [callbackBlock copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    
    void (^block)(id obj) = objc_getAssociatedObject(self, "dismissBlockCallback");
    if (block)
        objc_removeAssociatedObjects(block);
}

//Return YES if there is a block object
- (BOOL)performCallbackBlockWithObject:(id)object
{
    //get back the block object attribute we set earlier
    void (^block)(id obj) = objc_getAssociatedObject(self, "dismissBlockCallback");
    if (block) {
        block(object);
        return YES;
    }
    
    return NO;
}

@end
