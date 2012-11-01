//
//  SyPCamera.h
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SyPImageBuffer;

extern NSString * const SyPCameraAddedNotification;
extern NSString * const SyPCameraRemovedNotification;

typedef void(^SyPCameraImageHandler)(SyPImageBuffer *image);

@interface SyPCamera : NSObject
+ (NSSet *)cameras;
@property (readonly) NSString *name;
@property (readonly) NSString *identifier; // Unique per device and persistent
- (NSError *)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler;
- (NSError *)stopLiveView;
- (SyPImageBuffer *)newLiveViewImage;
@end

@interface SyPCamera (Subclassing)
+ (void)addCamera:(SyPCamera *)added;
+ (void)removeCamera:(SyPCamera *)removed;
@end