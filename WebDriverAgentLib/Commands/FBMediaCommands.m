#import "FBMediaCommands.h"

#import <Photos/Photos.h>
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"

static NSDictionary *FBMediaResult(BOOL ok, NSString *status, NSString *error)
{
  return @{@"ok": @(ok), @"status": status, @"error": error ?: (id)NSNull.null};
}

// Route handlers and completion updates are serialized on WDA's main queue.
static NSMutableDictionary<NSString *, NSDictionary *> *FBMediaJobs;
static BOOL FBMediaPermissionPending = NO;

@implementation FBMediaCommands

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/wda/saveToPhotos"].withoutSession
      respondWithTarget:self action:@selector(handleSaveToPhotos:)]
  ];
}

+ (id<FBResponsePayload>)handleSaveToPhotos:(FBRouteRequest *)request
{
  if (![request.arguments isKindOfClass:NSDictionary.class]) {
    return FBResponseWithObject(FBMediaResult(NO, @"invalidFile", @"Expected a JSON object."));
  }
  id input = request.arguments[@"file"];
  if (![input isKindOfClass:NSString.class] || [input length] == 0 ||
      [input length] > 200 || [input hasPrefix:@"."] ||
      [input rangeOfString:@"/"].location != NSNotFound ||
      [input rangeOfString:@"\\"].location != NSNotFound ||
      [input rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) {
    return FBResponseWithObject(FBMediaResult(NO, @"invalidFile", @"Use a plain filename, not a path."));
  }
  NSString *name = input;
  NSString *ext = name.pathExtension.lowercaseString;
  if (![@[@"jpg", @"jpeg", @"png", @"heic", @"mp4", @"mov"] containsObject:ext]) {
    return FBResponseWithObject(FBMediaResult(NO, @"unsupportedType", @"Allowed: jpg jpeg png heic mp4 mov."));
  }
  if (FBMediaJobs == nil) FBMediaJobs = [NSMutableDictionary dictionary];
  NSDictionary *existing = FBMediaJobs[name];
  if (existing != nil) return FBResponseWithObject(existing);

  NSFileManager *fm = NSFileManager.defaultManager;
  NSURL *documents = [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  NSURL *file = [documents URLByAppendingPathComponent:name isDirectory:NO];
  NSDictionary *attributes = [fm attributesOfItemAtPath:file.path error:nil];
  if (attributes == nil) {
    return FBResponseWithObject(FBMediaResult(NO, @"notFound", @"Upload the file to the WDA runner Documents directory first."));
  }
  if (![attributes[NSFileType] isEqual:NSFileTypeRegular] ||
      ![file.URLByResolvingSymlinksInPath.URLByDeletingLastPathComponent.path
        isEqual:documents.URLByResolvingSymlinksInPath.path] ||
      [attributes[NSFileSize] unsignedLongLongValue] == 0) {
    return FBResponseWithObject(FBMediaResult(NO, @"invalidFile", @"Expected a nonempty regular file directly in Documents; symlinks are not allowed."));
  }

  PHAuthorizationStatus permission = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
  if (permission == PHAuthorizationStatusNotDetermined) {
    if (!FBMediaPermissionPending) {
      FBMediaPermissionPending = YES;
      [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{ FBMediaPermissionPending = NO; });
      }];
    }
    return FBResponseWithObject(FBMediaResult(NO, @"notDetermined", @"Allow adding photos on the iPhone, then retry the same filename."));
  }
  if (permission == PHAuthorizationStatusDenied || permission == PHAuthorizationStatusRestricted) {
    return FBResponseWithObject(FBMediaResult(NO,
      permission == PHAuthorizationStatusDenied ? @"denied" : @"restricted",
      @"Photo access is unavailable. Check iPhone Settings for the WDA runner."));
  }
  if (permission != PHAuthorizationStatusAuthorized && permission != PHAuthorizationStatusLimited) {
    return FBResponseWithObject(FBMediaResult(NO, @"unauthorized", @"Unexpected Photos authorization state."));
  }

  FBMediaJobs[name] = FBMediaResult(NO, @"saving", nil);
  BOOL isVideo = [@[@"mp4", @"mov"] containsObject:ext];
  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
    PHAssetCreationRequest *creation = [PHAssetCreationRequest creationRequestForAsset];
    [creation addResourceWithType:isVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto
                         fileURL:file options:nil];
  } completionHandler:^(BOOL success, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (!success) {
        FBMediaJobs[name] = FBMediaResult(NO, @"saveFailed", error.localizedDescription ?: @"Photos rejected the media.");
        return;
      }
      NSError *removeError = nil;
      BOOL removed = [fm removeItemAtURL:file error:&removeError];
      FBMediaJobs[name] = FBMediaResult(YES, removed ? @"saved" : @"savedCleanupFailed",
                                      removed ? nil : removeError.localizedDescription);
    });
  }];
  // Pump the run loop instead of blocking the main queue used by Photos/UI.
  // A slow import stays in flight; repeat calls return its state, never import twice.
  [[[FBRunLoopSpinner new] timeout:25] spinUntilTrue:^BOOL{
    return ![FBMediaJobs[name][@"status"] isEqual:@"saving"];
  }];
  return FBResponseWithObject(FBMediaJobs[name]);
}
@end
