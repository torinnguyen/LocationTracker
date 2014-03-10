//
//  ServerApiManager.m
//
//  Created by Torin Nguyen on 10/03/2014.
//  Copyright (c) 2013 Torin Nguyen. All rights reserved.
//

#import "ServerApiManager.h"
#import "LocationTracker.h"

@interface ServerApiManager()
@end

@implementation ServerApiManager

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


#pragma mark - Business Logic

/*
 * This is a simple API to send location to server
 * You should add more user-identification formation to the API
 */
- (void)updateLocationToServerInBackground:(CLLocation *)location
{
    UIApplication* application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)] == NO)
        return;
    
    //Start a new background task
    UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
    bgTaskId = [application beginBackgroundTaskWithExpirationHandler:^{
        NSString * logMessage = [NSString stringWithFormat:@"force kill background task with id %lu", (unsigned long)bgTaskId];
        [self logStringToFile:logMessage];
        NSLog(@"%@", logMessage);
        [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
    }];
    
    NSString * logMessage = [NSString stringWithFormat:@"begin background task with id %lu", (unsigned long)bgTaskId];
    [self logStringToFile:logMessage];
    NSLog(@"%@", logMessage);
    
    //Construct the request url
    NSNumber * lat = @(location.coordinate.latitude);
    NSNumber * lon = @(location.coordinate.longitude);
    NSNumber * accuracy = @(location.horizontalAccuracy);
    NSString * urlString = [NSString stringWithFormat:@"http://torinnguyen.com/api_test/location.php?lat=%@&lon=%@&accuracy=%@", lat, lon, accuracy];
    
    //The request
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSURLResponse *response;
    NSError *err;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    NSString * responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    
    //Response
    logMessage = [NSString stringWithFormat:@"responseString: %@", responseString];
    [self logStringToFile:logMessage];
    NSLog(@"%@", logMessage);
    
    //Kill the background task
    logMessage = [NSString stringWithFormat:@"ending background task with id %lu", (unsigned long)bgTaskId];
    [self logStringToFile:logMessage];
    NSLog(@"%@", logMessage);
    
    [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
}



#pragma mark - Logging for Debug

- (void)logStringToFile:(NSString *)stringToLog
{
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

@end
