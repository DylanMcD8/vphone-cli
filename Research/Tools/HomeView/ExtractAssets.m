// Decode original CoreUI renditions using the host CoreUI framework.
// Method signatures checked against the installed macOS runtime.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>
@interface NSObject (AssetReading)
- (id)initWithURL:(NSURL *)url error:(NSError **)error;
- (id)imageWithName:(NSString *)name scaleFactor:(double)scale deviceIdiom:(NSInteger)idiom appearanceName:(NSString *)appearance;
- (CGImageRef)image;
@end
int main(int argc,const char **argv){@autoreleasepool{
 if(argc!=4)return 64;
 dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI",RTLD_NOW);
 NSError *error=nil; id catalog=[[NSClassFromString(@"CUICatalog") alloc] initWithURL:[NSURL fileURLWithPath:@(argv[1])] error:&error];
 if(!catalog){NSLog(@"%@",error);return 1;}
 NSArray *rows=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[2])] options:0 error:&error];
 NSFileManager *fm=NSFileManager.defaultManager; NSUInteger count=0,failed=0;
 for(NSDictionary *row in rows){@autoreleasepool{
  if(![row[@"AssetType"] isEqual:@"Image"])continue;
  NSString *name=row[@"Name"],*appearance=row[@"Appearance"];
  NSString *suffix=appearance.length?appearance:@"Light";
  NSString *relative=[NSString stringWithFormat:@"%@--%@--%@x.png",name,suffix,row[@"Scale"]?:@1];
  NSString *path=[@(argv[3]) stringByAppendingPathComponent:relative];
  @try{
   id named=[catalog imageWithName:name scaleFactor:[row[@"Scale"] doubleValue] deviceIdiom:0 appearanceName:appearance];
   CGImageRef image=[named image];
   if(!image||CGImageGetWidth(image)!=[row[@"PixelWidth"] unsignedIntegerValue]||CGImageGetHeight(image)!=[row[@"PixelHeight"] unsignedIntegerValue]){fprintf(stderr,"Missing or mismatched: %s\n",relative.UTF8String);failed++;continue;}
   [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
   CGImageDestinationRef dest=CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],CFSTR("public.png"),1,NULL);
   if(!dest){failed++;continue;} CGImageDestinationAddImage(dest,image,NULL);BOOL ok=CGImageDestinationFinalize(dest);CFRelease(dest);
   if(ok)count++;else failed++;
  }@catch(NSException *e){fprintf(stderr,"%s: %s\n",relative.UTF8String,e.reason.UTF8String);failed++;}
 }}
 printf("Exported %lu; failed %lu\n",count,failed);return failed?2:0;
}}
