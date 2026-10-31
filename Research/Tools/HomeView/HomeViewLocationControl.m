#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

// Native Settings API. vphoned itself never enables this switch.
@interface CLLocationManager (HomeViewControl)
+ (void)setLocationServicesEnabled:(BOOL)enabled;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *action = argc == 2 ? @(argv[1]) : @"";
        BOOL change = [action isEqual:@"enable"] || [action isEqual:@"disable"];
        if (!change && ![action isEqual:@"status"]) {
            fprintf(stderr, "usage: homeview-location-control status|enable|disable\n");
            return 2;
        }
        BOOL before = [CLLocationManager locationServicesEnabled];
        BOOL requested = [action isEqual:@"enable"];
        if (change) {
            if (![CLLocationManager respondsToSelector:@selector(setLocationServicesEnabled:)]) {
                fprintf(stderr, "This guest does not expose the Location Services setter.\n");
                return 1;
            }
            [CLLocationManager setLocationServicesEnabled:requested];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
        BOOL after = [CLLocationManager locationServicesEnabled];
        printf("{\"before\":%s,\"enabled\":%s}\n",
               before ? "true" : "false", after ? "true" : "false");
        return change && after != requested ? 1 : 0;
    }
}
