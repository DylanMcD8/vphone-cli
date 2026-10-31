#import <Foundation/Foundation.h>
#import <dlfcn.h>
@interface NSObject (PersonalContent)
+ (id)updateRequestForProfileIdentity:(id)identity allowPersonalContentAccess:(BOOL)allow;
- (id)allProfilesWithError:(NSError **)error;
- (void)updateProfileForRequest:(id)request completion:(void (^)(id,NSError*))completion;
- (id)allowPersonalContentAccess;
- (id)identity;
- (NSUUID *)identifier;
- (void)invalidate;
+ (id)fetchProfilesRequestForIdentity:(id)identity;
+ (id)allowPersonalContentAccessSettingKey;
+ (id)customNameSettingKey;
+ (id)settingRequestWithKey:(id)key;
- (void)setSettingRequests:(id)requests;
- (id)profileForFetchRequest:(id)request error:(NSError **)error;
@end
int main(int argc,char **argv){@autoreleasepool{
 if(argc<2)return 64;NSString *action=@(argv[1]);
 if(argc==2 && [action isEqual:@"list"]){
  dlopen("/System/Library/PrivateFrameworks/UserProfiles.framework/UserProfiles",RTLD_NOW|RTLD_LOCAL);
  id store=[NSClassFromString(@"UPProfileStore") new];NSError *error=nil;id profiles=[store allProfilesWithError:&error];if(error)return 1;
  NSMutableArray *entries=[NSMutableArray new];
  for(id p in profiles){NSString *uuid=[[(NSUUID *)[[p valueForKey:@"identity"] valueForKey:@"identifier"] UUIDString] copy];
   if(uuid){id fetch=[NSClassFromString(@"UPFetchProfilesRequest") fetchProfilesRequestForIdentity:[p valueForKey:@"identity"]];
    id keyClass=NSClassFromString(@"UPSettingKey");id detailed=p;
    if([keyClass respondsToSelector:@selector(customNameSettingKey)]){
     id key=[keyClass customNameSettingKey];[fetch setSettingRequests:[NSSet setWithObject:[NSClassFromString(@"UPSettingRequest") settingRequestWithKey:key]]];
     detailed=[store profileForFetchRequest:fetch error:nil]?:p;
    }
    id name=[detailed valueForKey:@"customName"];
    [entries addObject:@{@"id":uuid,@"name":[name isKindOfClass:NSString.class]?name:uuid}];}}
  NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"profiles":entries} options:0 error:nil];puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);[store invalidate];return 0;
 }
 if(argc!=3)return 64;NSString *uuid=@(argv[2]);
 if(![@[@"status",@"enable",@"disable"] containsObject:action])return 64;
 dlopen("/System/Library/PrivateFrameworks/UserProfiles.framework/UserProfiles",RTLD_NOW|RTLD_LOCAL);
 id store=[NSClassFromString(@"UPProfileStore") new];NSError *error=nil;id profiles=[store allProfilesWithError:&error];if(error)return 1;
 id profile=nil;for(id p in profiles)if([[(NSUUID *)[[p valueForKey:@"identity"] valueForKey:@"identifier"] UUIDString] isEqual:uuid])profile=p;
 if(!profile){fprintf(stderr,"Requested local profile does not exist\n");return 2;}
 id fetch=[NSClassFromString(@"UPFetchProfilesRequest") fetchProfilesRequestForIdentity:[profile valueForKey:@"identity"]];
 id key=[NSClassFromString(@"UPSettingKey") allowPersonalContentAccessSettingKey];
 [fetch setSettingRequests:[NSSet setWithObject:[NSClassFromString(@"UPSettingRequest") settingRequestWithKey:key]]];
 profile=[store profileForFetchRequest:fetch error:&error];if(!profile||error)return 6;
 id before=[profile allowPersonalContentAccess];
 if(![action isEqual:@"status"]){
  id request=[NSClassFromString(@"UPUpdateProfileRequest") updateRequestForProfileIdentity:[profile valueForKey:@"identity"] allowPersonalContentAccess:[action isEqual:@"enable"]];
  dispatch_semaphore_t done=dispatch_semaphore_create(0);__block BOOL success=NO;
  [store updateProfileForRequest:request completion:^(id updated,NSError *e){success=updated!=nil&&e==nil;if(e)NSLog(@"%@",e);dispatch_semaphore_signal(done);}];
  if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC))||!success)return 3;
 }
 [store invalidate];store=[NSClassFromString(@"UPProfileStore") new];profiles=[store allProfilesWithError:&error];if(error)return 4;
 profile=nil;for(id p in profiles)if([[(NSUUID *)[[p valueForKey:@"identity"] valueForKey:@"identifier"] UUIDString] isEqual:uuid])profile=p;if(!profile)return 5;
 profile=[store profileForFetchRequest:fetch error:&error];if(!profile||error)return 7;
 id after=[profile allowPersonalContentAccess];NSDictionary *result=@{@"profile":uuid,@"previous":before?:NSNull.null,@"current":after?:NSNull.null};
 NSData *data=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
 [store invalidate];if(![action isEqual:@"status"]&&(![after isKindOfClass:NSNumber.class]||[after boolValue]!=[action isEqual:@"enable"]))return 8;return 0;
}}
