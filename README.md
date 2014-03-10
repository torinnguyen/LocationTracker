This is a sample project to handle the most commonly use-case for Location Service on iOS: track location & send updates to server.

### Usage note:

- In foreground mode, the Location Service is started every minute for a duration of 10 second. This implementation saves significant battery according to the original author of the code. I kept the behaviour and added a few convenient configurations for easy usage.
- In background mode, the app receives location updates with default behaviors from iOS, not much can be changed here. I
- LocationTracker use block-based callback implementation, you may implement server API call here, as in the sample project; remember to keep it short.
- LocationTracker's minimumCallBackInterval determine how often the callback block is triggered. Default to 60 seconds since the sample application is performing server calls. You may change this to smaller value for less expensive business logic such as saving to a local log file instead of to server)
- Log file records almost every activity in the app. Without this, it would be difficult to troubleshoot the update intervals.


### Original project:

Most of the code was based on this guide/project

http://mobileoop.com/background-location-update-programming-for-ios-7


### Other references:

http://stackoverflow.com/questions/3421242/behaviour-for-significant-change-location-api-when-terminated-suspended

http://stackoverflow.com/questions/18901583/start-location-manager-in-ios-7-from-background-task

[![screenshot](https://github.com/torinnguyen/LocationTracker/raw/master/screenshot.png)](#features)
