//
//  SyPGPhotoContext.h
//  CameraService
//
//  Created by Tom Butterworth on 29/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct _GPContext GPContext;

@class SyPGPhotoCamera;

@interface SyPGPhotoContext : NSObject
@property (readonly) GPContext *GPContext;
- (NSSet<NSDictionary<NSString *, id> *> *)getConnectedCameraInfo;
- (SyPGPhotoCamera * _Nullable)cameraForDescription:(NSDictionary<NSString *,id> *)description withError:(NSError **)error;
@end

@interface SyPGPhotoContext (GPhoto)
+ (NSError * _Nullable)errorForResult:(int)result;
+ (BOOL)errorIsFatal:(NSError *)error;
- (void)use:(NSDictionary<NSString *, id> *)camera;
- (void)end:(NSDictionary<NSString *, id> *)camera;
@end
NS_ASSUME_NONNULL_END
