//
//  LocationTracker.h
//  Location
//
//  Created by Rick. Modified by Torin Nguyen
//  Copyright (c) 2014 Location. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationTracker : NSObject

@property (nonatomic, strong) NSMutableArray * myLocationArray;
@property (nonatomic, assign) NSUInteger maxLocationHistory;

@property (nonatomic, strong) CLLocation * myLastLocation;
@property (nonatomic, strong) NSDate * myLastLocationTime;

@property (nonatomic, assign) NSTimeInterval minimumCallBackIntervalForeground;
@property (nonatomic, assign) NSTimeInterval minimumCallBackIntervalBackground;

+ (instancetype)sharedInstance;

- (void)startLocationTracking;
- (void)startLocationTrackingWithInterval:(NSTimeInterval)seconds;
- (void)stopLocationTracking;

/*
 * A generic block-based callback mechanism
 */
- (void)setCallbackBlock:(void (^)(id object))callbackBlock;
- (BOOL)performCallbackBlockWithObject:(id)object;

@end
