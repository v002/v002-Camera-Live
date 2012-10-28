//
//  SyPCamera.h
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SyPImageBuffer;

typedef void(^SyPCameraImageHandler)(id camera, SyPImageBuffer *image);

@interface SyPCamera : NSObject
@property (readonly) NSString *name;
- (NSError *)startLiveViewWithHandler:(SyPCameraImageHandler)handler;
- (NSError *)stopLiveView;
- (SyPImageBuffer *)newLiveViewImage;
@end
