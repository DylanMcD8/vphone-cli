// Cosmetic SystemStatus override for a HomeView research guest. No radio/network changes.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <unistd.h>

@interface NSObject (HomeViewSystemStatus)
- (id)data;
- (void)observeDataWithBlock:(void(^)(id))block;
- (void)setVolatileData:(id)data;
- (void)setWifiActive:(BOOL)value;
- (void)setSignalStrengthBars:(NSUInteger)value;
- (BOOL)isWifiActive;
- (NSUInteger)signalStrengthBars;
- (void)invalidate;
@end

static void settle(void) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
}

int main(int argc, char **argv) { @autoreleasepool {
    setgid(501); setuid(501);
    if (argc != 2 || (strcmp(argv[1], "enable") && strcmp(argv[1], "disable") && strcmp(argv[1], "status"))) {
        fputs("Usage: homeview-wifi-indicator status|enable|disable\n", stderr);
        return 2;
    }
    if (!dlopen("/System/Library/PrivateFrameworks/SystemStatus.framework/SystemStatus", RTLD_NOW|RTLD_LOCAL)) return 3;
    Class observerClass = NSClassFromString(@"STWifiStatusDomain");
    Class publisherClass = NSClassFromString(@"STWifiStatusDomainPublisher");
    Class dataClass = NSClassFromString(@"STMutableWifiStatusDomainData");
    if (!observerClass || !publisherClass || !dataClass) return 4;
    id observer = [observerClass new];
    __block id observed = nil;
    if (![observer respondsToSelector:@selector(observeDataWithBlock:)]) return 7;
    [observer observeDataWithBlock:^(id data) { observed = data; }];
    BOOL enabled = strcmp(argv[1], "enable") == 0;
    id publisher = [publisherClass new];
    BOOL change = strcmp(argv[1], "status") != 0;
    if (change) {
        id data = [dataClass new];
        [data setWifiActive:enabled];
        [data setSignalStrengthBars:enabled ? 3 : 0];
        [publisher setVolatileData:data];
    }
    for (int i = 0; i < 5; i++) {
        settle();
        observed = [observer data] ?: observed;
        if (observed && (!change || [observed isWifiActive] == enabled)) break;
    }
    if (!observed) { fputs("No SystemStatus response\n", stderr); return 5; }
    BOOL verified = !change || ([observed isWifiActive] == enabled && [observed signalStrengthBars] == (enabled ? 3 : 0));
    NSDictionary *result = @{@"wifiActive": @([observed isWifiActive]),
                             @"signalStrengthBars": @([observed signalStrengthBars]),
                             @"verified": @(verified), @"cosmeticOnly": @YES};
    NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingSortedKeys error:nil];
    puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
    [publisher invalidate];
    [observer invalidate];
    return verified ? 0 : 6;
}}
