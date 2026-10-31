#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>
@interface NSObject (HomeModular)
- (id)fetchActivePosterForRole:(NSString *)role error:(NSError **)error;
- (void)fetchPosterConfigurationsForRole:(NSString *)role completion:(void (^)(id,id))completion;
- (void)createPosterConfigurationForProviderIdentifier:(NSString *)provider posterDescriptorIdentifier:(NSString *)descriptor role:(NSString *)role completion:(void (^)(id,id))completion;
- (void)updateToSelectedConfigurationMatchingUUID:(id)uuid role:(NSString *)role completion:(void (^)(id))completion;
- (id)serverUUID;
@end
static void printResult(id value,id error){
 NSDictionary *r=@{@"value":[value description]?:@"null",@"error":[error description]?:@"null"};
 NSData *d=[NSJSONSerialization dataWithJSONObject:r options:0 error:nil];puts([[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);
}
int main(int argc,char **argv){@autoreleasepool{
 setgid(501);setuid(501);
 dlopen("/System/Library/PrivateFrameworks/PosterBoardServices.framework/PosterBoardServices",RTLD_LAZY|RTLD_GLOBAL);
 id s=[NSClassFromString(@"PRSService") new];NSString *role=@"PRPosterRoleAmbient",*action=argc>1?@(argv[1]):@"active";
 if([action isEqual:@"active"]){NSError *e=nil;id a=[s fetchActivePosterForRole:role error:&e];printResult(a,e);return e?1:0;}
 __block BOOL done=NO,failed=NO;
 if([action isEqual:@"list"])[s fetchPosterConfigurationsForRole:role completion:^(id a,id e){printResult(a,e);done=YES;}];
 else if([action isEqual:@"create"]&&argc>2)[s createPosterConfigurationForProviderIdentifier:@"com.apple.Home.HomeFace" posterDescriptorIdentifier:@(argv[2]) role:role completion:^(id a,id e){printResult(a,e);if(a)printResult([a serverUUID],nil);done=YES;}];
 else if([action isEqual:@"create-provider"]&&argc==4)[s createPosterConfigurationForProviderIdentifier:@(argv[2]) posterDescriptorIdentifier:@(argv[3]) role:role completion:^(id a,id e){printResult(a,e);if(a)printResult([a serverUUID],nil);failed=e!=nil||a==nil;done=YES;}];
 else if([action isEqual:@"select"]&&argc>2)[s updateToSelectedConfigurationMatchingUUID:[[NSUUID alloc]initWithUUIDString:@(argv[2])] role:role completion:^(id e){printResult(@"selection completed",e);done=YES;}];
 else return 2;
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:25];while(!done&&deadline.timeIntervalSinceNow>0)[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
 if(!done){printResult(nil,@"Timed out");return 3;}
 if(failed)return 1;
}return 0;}
