//
//  ServerApiManager.h
//
//  Created by Torin Nguyen on 10/03/2014.
//  Copyright (c) 2014 Torin Nguyen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface ServerApiManager : NSObject

+ (instancetype)sharedInstance;

- (void)updateLocationToServerInBackground:(CLLocation *)location;

@end
