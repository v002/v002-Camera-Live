//
//  SyPCamera.m
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPCamera.h"

NSString * const SyPCameraAddedNotification = @"SyPCameraAddedNotification";
NSString * const SyPCameraRemovedNotification = @"SyPCameraRemovedNotification";

@implementation SyPCamera

+ (NSMutableSet *)mutableCameras
{
    static NSMutableSet *mCameras = nil;
    if (mCameras == nil)
    {
        mCameras = [[NSMutableSet alloc] initWithCapacity:1];
    }
    return mCameras;
}

+ (void)addCamera:(SyPCamera *)added
{
    @synchronized([self class]) {
        [[self mutableCameras] addObject:added];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SyPCameraAddedNotification object:added];
}

+ (void)removeCamera:(SyPCamera *)removed
{
    [removed retain];
    @synchronized([self class]) {
       [[self mutableCameras] removeObject:removed];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SyPCameraRemovedNotification object:removed];
    [removed release];
}

+ (NSSet *)cameras
{
    NSSet *cameras;
    @synchronized(self) {
        cameras = [self mutableCameras];
    }
    return cameras;
}

- (NSString *)name { return @""; }
- (NSString *)identifier { return @""; }
- (NSError *)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler { return nil; }
- (NSError *)stopLiveView { return nil; }
- (SyPImageBuffer *)newLiveViewImage { return nil; }
@end
